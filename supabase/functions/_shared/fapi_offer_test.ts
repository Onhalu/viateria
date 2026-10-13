import { assertEquals } from "jsr:@std/assert@1.0.11";
import {
  extractFormResource,
  formPathFromSaleUrl,
  offerFromFormResource,
  scriptUrlForSaleForm,
} from "./fapi_offer.ts";

const now = new Date("2026-10-13T12:00:00.000Z");

Deno.test("form path comes from id, path, or the last URL segment", () => {
  assertEquals(
    formPathFromSaleUrl(
      "https://form.fapi.cz/?id=10df6f32-5c5d-4ca3-9151-a1c6f28da166",
    ),
    "10df6f32-5c5d-4ca3-9151-a1c6f28da166",
  );
  assertEquals(
    formPathFromSaleUrl("https://form.fapi.cz/?path=diploma-form"),
    "diploma-form",
  );
  assertEquals(
    scriptUrlForSaleForm("https://form.fapi.cz/medal-test"),
    "https://form.fapi.cz/script.php?id=medal-test",
  );
});

Deno.test("script attribute decodes the embedded form resource", () => {
  const script = [
    "formWrapper.setAttribute('data-form-resource', \"",
    '{\\"id\\":1,\\"name\\":\\"Kari\\u00e9ra\\"}',
    "\");",
  ].join("");
  const resource = extractFormResource(script);
  assertEquals(resource?.id, 1);
  assertEquals(resource?.name, "Kariéra");
});

Deno.test("one_time price is cents; an expired special price is ignored", () => {
  const offer = offerFromFormResource({
    currency_code: "EUR",
    show_prices_including_vat: true,
    allow_terms: true,
    terms_url: "https://example.com/terms",
    items: {
      "1": { id: 1, item_template: 9, required: false },
    },
    item_templates: {
      "9": {
        id: 9,
        vat: 0,
        including_vat: true,
        prices: [
          { type: "one_time", price: 190, currency_code: "EUR" },
          {
            type: "special_one_time",
            price: 150,
            currency_code: "EUR",
            metadata: { special_price: { end_date: "2026-02-28" } },
          },
        ],
      },
    },
    purposes: [
      {
        is_primary: true,
        checkbox_label:
          '<a href="https://example.com/privacy">Privacy notice</a>',
        link_href: null,
      },
    ],
  }, now);
  assertEquals(offer.price_cents, 19000);
  assertEquals(offer.currency, "eur");
  assertEquals(offer.terms_url, "https://example.com/terms");
  assertEquals(offer.terms[0]?.text, "Privacy notice");
  assertEquals(offer.terms[0]?.url, "https://example.com/privacy");
  assertEquals(offer.terms[1]?.url, "https://example.com/terms");
});

Deno.test("an active special price replaces one_time and zero stays zero", () => {
  const special = offerFromFormResource({
    currency_code: "CZK",
    items: [{ id: 1, item_template: 2, required: true }],
    item_templates: [{
      id: 2,
      including_vat: false,
      vat: 21,
      prices: [
        { type: "one_time", price: 100, currency_code: "CZK" },
        {
          type: "special_one_time",
          price: 50,
          currency_code: "CZK",
          metadata: {
            special_price: { begin_date: "2026-10-01", end_date: "2026-10-31" },
          },
        },
      ],
    }],
  }, now);
  assertEquals(special.price_cents, 6050);

  const free = offerFromFormResource({
    currency_code: "EUR",
    items: { "1": { id: 1, item_template: 3, required: false } },
    item_templates: {
      "3": {
        id: 3,
        including_vat: true,
        prices: [{ type: "one_time", price: 0, currency_code: "EUR" }],
      },
    },
  }, now);
  assertEquals(free.price_cents, 0);
  assertEquals(free.currency, "eur");
});

Deno.test("only required items are summed when the form marks one", () => {
  const offer = offerFromFormResource({
    currency_code: "EUR",
    items: {
      "1": { id: 1, item_template: 1, required: false },
      "2": { id: 2, item_template: 2, required: true },
    },
    item_templates: {
      "1": {
        id: 1,
        including_vat: true,
        prices: [{ type: "one_time", price: 10, currency_code: "EUR" }],
      },
      "2": {
        id: 2,
        including_vat: true,
        prices: [{ type: "one_time", price: 4.5, currency_code: "EUR" }],
      },
    },
  }, now);
  assertEquals(offer.price_cents, 450);
});
