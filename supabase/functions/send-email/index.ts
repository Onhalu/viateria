import { Webhook } from "https://esm.sh/standardwebhooks@1.0.0";
import { hookSecretBytes } from "./hook_auth.ts";

/**
 * Supabase Auth Send Email hook → SmartEmailing.
 *
 * Fail closed: `SEND_EMAIL_HOOK_SECRET` must be set and the Standard Webhooks
 * signature must verify. A missing or invalid secret returns 401 and does
 * not send. The previous live deploy parsed the JSON body when the secret
 * was unset.
 *
 * Set the secret to the same value as Auth → Hooks → Send Email (do not
 * invent a second one). SmartEmailing credentials stay in
 * `SMARTEMAILING_API_KEY` and optional `SMARTEMAILING_USERNAME` /
 * `SMARTEMAILING_EMAIL_ID` / `SMARTEMAILING_FROM` / `SMARTEMAILING_FROM_NAME`.
 */

const PROJECT_REF = "yzmbxxgesnbsqygzgdky";
const API = "https://app.smartemailing.cz/api/v3";
let cachedEmailId: number | null = null;

declare const EdgeRuntime: {
  waitUntil(promise: Promise<unknown>): void;
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function subjectFor(type: string) {
  switch (type) {
    case "signup":
      return "Potvrďte registraci ve Viateria";
    case "recovery":
      return "Obnovení hesla ve Viateria";
    case "magiclink":
    case "email":
      return "Přihlášení do Viateria";
    case "invite":
      return "Pozvánka do Viateria";
    case "email_change":
      return "Potvrďte změnu e-mailu ve Viateria";
    case "reauthentication":
      return "Ověřovací kód Viateria";
    default:
      return "Viateria";
  }
}

function confirmationUrl(tokenHash: string, type: string, redirectTo: string) {
  const params = new URLSearchParams({
    token: tokenHash,
    type,
    redirect_to: redirectTo || "",
  });
  return `https://${PROJECT_REF}.supabase.co/auth/v1/verify?${params.toString()}`;
}

function authHeader() {
  const username = Deno.env.get("SMARTEMAILING_USERNAME") ?? "onhalu@gmail.com";
  const apiKey = Deno.env.get("SMARTEMAILING_API_KEY") ?? "";
  if (!apiKey) throw new Error("SMARTEMAILING_API_KEY is not set");
  return {
    Authorization: `Basic ${btoa(`${username}:${apiKey}`)}`,
    "Content-Type": "application/json",
    Accept: "application/json",
  };
}

async function se(path: string, init: RequestInit = {}) {
  const response = await fetch(`${API}${path}`, {
    ...init,
    headers: { ...authHeader(), ...(init.headers ?? {}) },
  });
  const text = await response.text();
  if (!response.ok) {
    throw new Error(`SmartEmailing ${response.status}: ${text.slice(0, 400)}`);
  }
  return text ? JSON.parse(text) : {};
}

async function emailId() {
  if (cachedEmailId) return cachedEmailId;
  const configured = Deno.env.get("SMARTEMAILING_EMAIL_ID");
  if (configured) {
    cachedEmailId = Number(configured);
    return cachedEmailId;
  }

  const listed = await se("/emails?limit=10");
  const rows = Array.isArray(listed?.data) ? listed.data : [];
  const named = rows.find((row: { name?: string }) => row.name === "viateria-auth");
  const id = named?.id ?? rows[0]?.id;
  if (id) {
    cachedEmailId = Number(id);
    return cachedEmailId;
  }

  const created = await se("/emails", {
    method: "POST",
    body: JSON.stringify({
      name: "viateria-auth",
      title: "Viateria",
      htmlbody: "<html><body>{{content}}</body></html>",
      textbody: "{{content}}",
      template: true,
    }),
  });
  const createdId = created?.data?.id ?? created?.id;
  if (!createdId) throw new Error("SmartEmailing email template was not created");
  cachedEmailId = Number(createdId);
  return cachedEmailId;
}

async function sendViaSmartEmailing(
  to: string,
  subject: string,
  text: string,
  html: string,
) {
  const from = Deno.env.get("SMARTEMAILING_FROM") ?? "ahoj@vyslapni.cz";
  const senderName = Deno.env.get("SMARTEMAILING_FROM_NAME") ?? "Viateria";
  if (!to) throw new Error("missing recipient");

  const id = await emailId();
  await se("/send/transactional-emails-bulk", {
    method: "POST",
    body: JSON.stringify({
      sender_credentials: {
        from,
        reply_to: from,
        sender_name: senderName,
      },
      tag: "viateria-auth",
      email_id: id,
      message_contents: {
        subject,
        text_body: text,
        html_body: html,
      },
      tasks: [
        {
          recipient: { emailaddress: to },
          replace: [
            { key: "content", content: html },
            { key: "text", content: text },
            { key: "subject", content: subject },
          ],
          attachments: [],
        },
      ],
    }),
  });
}

function otpMail(token: string, url: string) {
  const text = [
    "Viateria",
    "",
    `Kód: ${token}`,
    "",
    "Zadejte ho v aplikaci, nebo otevřete odkaz:",
    url,
  ].join("\n");
  const html =
    `<p>Kód pro Viateria:</p><p style="font-size:28px;letter-spacing:4px"><strong>${token}</strong></p><p><a href="${url}">Potvrdit e-mail</a></p>`;
  return { text, html };
}

type HookUser = { email?: string; new_email?: string };
type HookEmail = {
  token?: string;
  token_hash?: string;
  token_new?: string;
  token_hash_new?: string;
  redirect_to?: string;
  email_action_type: string;
};

async function handle(user: HookUser, emailData: HookEmail) {
  const type = emailData.email_action_type;
  if (type.endsWith("_notification")) {
    await sendViaSmartEmailing(
      user.email ?? "",
      "Viateria",
      "Ve vašem účtu Viateria došlo ke změně.",
      "<p>Ve vašem účtu Viateria došlo ke změně.</p>",
    );
    return;
  }

  if (type === "email_change" && emailData.token_new && user.new_email) {
    const current = otpMail(
      emailData.token || "",
      confirmationUrl(
        emailData.token_hash_new || "",
        type,
        emailData.redirect_to || "",
      ),
    );
    const next = otpMail(
      emailData.token_new,
      confirmationUrl(
        emailData.token_hash || "",
        type,
        emailData.redirect_to || "",
      ),
    );
    await sendViaSmartEmailing(
      user.email ?? "",
      subjectFor(type),
      current.text,
      current.html,
    );
    await sendViaSmartEmailing(
      user.new_email,
      subjectFor(type),
      next.text,
      next.html,
    );
    return;
  }

  const token = emailData.token || emailData.token_new || "";
  const hash = emailData.token_hash || emailData.token_hash_new || "";
  const mail = otpMail(
    token,
    confirmationUrl(hash, type, emailData.redirect_to || ""),
  );
  await sendViaSmartEmailing(
    user.email ?? "",
    subjectFor(type),
    mail.text,
    mail.html,
  );
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("not allowed", { status: 400 });

  const payload = await req.text();
  const headers = Object.fromEntries(req.headers);
  const hookSecret = hookSecretBytes(Deno.env.get("SEND_EMAIL_HOOK_SECRET"));
  if (!hookSecret) {
    console.error("send-email rejected: SEND_EMAIL_HOOK_SECRET is not set");
    return json({
      error: { http_code: 401, message: "webhook secret missing" },
    }, 401);
  }

  try {
    const verified = new Webhook(hookSecret).verify(payload, headers) as {
      user: HookUser;
      email_data: HookEmail;
    };
    const work = handle(verified.user, verified.email_data).catch((error) => {
      console.error(error instanceof Error ? error.message : "send failed");
    });
    // Auth hook must return 200 within 5s. SmartEmailing is slower.
    EdgeRuntime.waitUntil(work);
  } catch (error) {
    console.error(
      "send-email rejected: invalid webhook signature",
      error instanceof Error ? error.message : "send failed",
    );
    return json({
      error: { http_code: 401, message: "invalid webhook signature" },
    }, 401);
  }

  return json({});
});
