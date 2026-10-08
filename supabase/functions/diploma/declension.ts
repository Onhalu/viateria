/**
 * Czech accusative of the first name. 1:1 with `private.cs_accusative`
 * (migration 0026) and the original sklonovani() heuristic.
 * Surname is unchanged. SQL applies this only while the diploma still
 * follows the profile. A one-time edit is stored already final and must
 * not be passed through this function again.
 */
const IRREGULAR: Record<string, string> = {
  pavel: "pavla",
  "jiří": "jiřího",
  karel: "karla",
  marek: "marka",
  "františek": "františka",
  hynek: "hynka",
  "lukáš": "lukáše",
  "mikuláš": "mikuláše",
  "ondřej": "ondřeje",
  "matěj": "matěje",
  "tomáš": "tomáše",
  alex: "alexe",
  felix: "felixe",
};

const MALE_A = new Set([
  "nikola",
  "saša",
  "ilja",
  "luka",
  "luca",
  "mika",
  "sása",
]);

function isTitleCase(first: string, lower: string): boolean {
  if (!lower) return false;
  const titled = lower[0].toLocaleUpperCase("cs") + lower.slice(1);
  return first === titled;
}

export function csAccusative(fullName: string | null | undefined): string | null {
  const trimmed = (fullName ?? "").trim();
  if (!trimmed) return null;
  const name = trimmed.replace(/\s+/g, " ");
  const space = name.indexOf(" ");
  const first = space === -1 ? name : name.slice(0, space);
  const tail = space === -1 ? "" : name.slice(space + 1);
  const lower = first.toLocaleLowerCase("cs");

  let declined: string;
  const irregular = IRREGULAR[lower];
  if (irregular) {
    declined = irregular;
  } else {
    const female = !MALE_A.has(lower) &&
      (/(?:a|á|ia)$/u.test(lower) || /ie$/u.test(lower));
    if (female) {
      if (/(?:a|á)$/u.test(lower)) declined = `${lower.slice(0, -1)}u`;
      else if (/ie$/u.test(lower)) declined = `${lower.slice(0, -2)}ii`;
      else declined = lower;
    } else if (/ek$/u.test(lower)) {
      declined = `${lower.slice(0, -2)}ka`;
    } else if (MALE_A.has(lower)) {
      declined = `${lower.slice(0, -1)}u`;
    } else if (/o$/u.test(lower)) {
      declined = `${lower.slice(0, -1)}a`;
    } else if (/(?:š|č|ž|j|x|s|z|c)$/u.test(lower)) {
      declined = `${lower}e`;
    } else {
      declined = `${lower}a`;
    }
  }

  const upper = first.toLocaleUpperCase("cs");
  if (first === upper && first !== lower) {
    declined = declined.toLocaleUpperCase("cs");
  } else if (isTitleCase(first, lower)) {
    declined = declined[0].toLocaleUpperCase("cs") + declined.slice(1);
  }

  return tail ? `${declined} ${tail}` : declined;
}
