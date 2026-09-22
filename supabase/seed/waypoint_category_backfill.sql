-- Backfill public.waypoints.category from assets/map/pois.geojson.
--
-- Live snapshot 2026-09-22: 80 waypoint rows, all still on the column default
-- 'historical'. Each row was matched as follows:
--   1. Nearest GeoJSON feature by haversine distance on lat/lng.
--   2. Keep that feature's properties.category when distance <= 150 m.
--   3. Otherwise, if the Czech title folds (NFKD, strip diacritics, lower-case)
--      to exactly one properties.name and that name has a single category,
--      use it.
--   4. Otherwise leave 'historical'.
--
-- Result: 79 rows within 150 m (78 at 0 m, Hazmburk at 36.2 m).
-- One row had no POI inside 150 m:
--   0681a14a-974d-4bcb-8ef8-cb9c724eafb4 Velká Deštná
--   nearest same-name POI is 1877 m away (nature). Name fallback applied.
-- Nothing stayed historical for lack of a match. City and technical had
-- zero hits in this snapshot; the check constraint still allows them.
--
-- Idempotent: re-running sets the same category on these ids.
-- Rows inserted later are not covered; classify those the same way.

-- city: no rows in this snapshot

-- nature: 55
update public.waypoints
set category = 'nature'
where id in (
  '92bc5769-3e7b-4233-9b78-5d5caf5aa99a', -- Devět skal
  'cc24f1cb-5a03-4d2d-b74d-0f7ed64c17a8', -- Bretschneiderovo ucho
  '48c18069-ef12-4f5a-b44b-c73e48e06ff8', -- Míchova skála
  '58e82f7b-619d-4ac8-8daa-aa6ec3717b13', -- Rodrigova skála
  '72e81392-617f-4543-b9e8-993fa78f5bee', -- Velká Javořina
  'd61176c5-7ce2-4fa2-be31-ce6b9029401c', -- Rozhledna Velký Lopeník
  'e3a417c2-c8e3-4ad4-9fcb-a1a3187bd417', -- Býčí skála
  'b7a71a9f-34b9-4f45-9202-35628f93efc6', -- Velká Deštná
  '764a5e57-7693-4795-b7d4-fa3120a2a21e', -- Rozhledna Andrlův Chlum
  '4865ece2-3019-47f5-9093-d8a368a1d289', -- Koruna
  'e794eac3-4b46-4bbe-9b1a-c90bf4410c11', -- Rozhledna Osičina
  '9beca981-6628-43f5-9f64-fe6cf561632c', -- Rozhledna Skuhrov nad Bělou
  'c3c457cb-a7c5-40ba-8b71-07abecb77ecc', -- Tyršova rozhledna (Rozálka)
  '9ab840e0-756d-43cc-874f-dd4ee6d9a2d9', -- Ledříčkova skála
  '43609c28-6764-47de-84ca-3cc199b6784a', -- Rozhledna Vrbice
  '7373dad5-8f55-4309-a6bc-552bd675e087', -- Devět skal
  'e1ef85d0-8119-4715-80bc-4cb427bdc713', -- Bretschneiderovo ucho
  '00f6cc2d-8fc4-42d5-baa0-d8774145b212', -- Wilsonova skála
  'c6a639bc-87e5-496f-9a9d-722bbe648152', -- Míchova skála
  '92d6040c-9005-4f69-8815-c76273c13b71', -- Rozhledna Fajtův kopec
  '5563f135-c980-442b-8979-49aaa7a37122', -- Rozhledna Na Pekelném kopci
  '64bbd0ab-7a32-419c-966e-09dbee1221dc', -- Rodrigova skála
  '79a48cdc-2fab-4f73-a8f2-ac00d229793a', -- Menhir Smolíček
  '794c0431-f557-410f-896c-125fc29b8a20', -- Milešovka
  '13e1ff52-4556-4b6d-bd9d-c3d41d79e142', -- Kounovské kamenné řady
  '646eb833-20fd-4045-82c8-44d94d76621d', -- Rozhledna Rubín
  '05c65ffe-dfb2-40fc-9e00-48b18c8c2243', -- Kreuzberg
  'd3a1078e-efbb-4d22-b50f-61965c930241', -- Svatý kopeček
  '3eba9ba7-8b59-4b4d-9279-2937f6795619', -- Děvín
  'cedad040-6bcc-46a2-97e9-3b377c4fb763', -- Rozhledna Dalibor
  '07c81ba4-9dfc-43f0-a912-203c6706693e', -- Rozhledna Holedná
  '17cefb52-f175-487d-879b-99133c920cbc', -- Rozhledna Vartovna
  'adbe4113-4fb8-4acd-84cc-2814190ec6ec', -- Rozhledna Cvilín
  '9a8d9d57-2da5-43a9-bbe1-f62f328308d5', -- Blatenský vrch
  'dfb3d58b-0300-47bc-a79d-d251d22eecb5', -- Rozhledna Bramberk
  '436fe0c5-a3bb-4baf-bd01-2b81af60975e', -- Haniperk
  '29764619-d0a7-4c88-a513-54e662b92180', -- Rozhledna Janov u Děčína
  '0681a14a-974d-4bcb-8ef8-cb9c724eafb4', -- Velká Deštná
  'a5185a0c-2a9f-41e6-8454-131f647d47e8', -- Vysoký vrch
  'caa0efab-811d-4dfb-a7a2-bc077db9e60f', -- Dalimilova rozhledna
  'fe9ebf1b-d22d-4415-8876-9d22c1b76aad', -- Malý Smrk
  'ca0d4355-7f8b-48ca-8592-6ca9332d6a1b', -- Magurka
  '6d181aca-ec23-456a-b31e-896bacb70182', -- Smrk
  'ec862556-eb29-4518-8579-4899e274cbdc', -- Lysá hora
  '8b79e7d0-45bf-4431-a2c9-21253b46c213', -- Radhošť
  'c0a7c49c-e472-484c-ac02-ee08b91b3744', -- Malchor
  '26cb0f70-609e-45b8-9d7e-41f74eaff264', -- Čertův mlýn
  'a65c6627-7650-41bc-a339-d38cd68e2983', -- Travný
  '225a6cb7-35f2-4a5a-9bd1-5ad59bd22231', -- Tanečnice
  '643483ff-4b84-4e02-b598-f0e8038543af', -- Tanečnice
  '82fbd0fc-6fe5-40e4-a5aa-bfb63ff7c379', -- Rozhledna Velký Javorník
  '416e2a18-5825-4de0-ab97-f27587256bda', -- Smrk
  '5df25454-7e7f-43a7-b80d-7beb66d17ccf', -- Lysá hora
  '8723d406-25cd-467a-91f9-0724be46e14e', -- Radhošť
  'ea557545-bffc-48dd-b46a-1e8b2fa5be42' -- Čertův mlýn
);

-- technical: no rows in this snapshot

-- historical: 25
update public.waypoints
set category = 'historical'
where id in (
  '95f6584b-45be-4b57-9af8-12a10b2a2a2d', -- Zelená Hora
  '117c2e37-3f92-44bd-8652-a36f27b5b83d', -- Zřícenina tvrze Melechov
  '30d032e4-8e30-4673-8f9b-e20373d8f12b', -- Kaple sv. Barbory + Buchlov
  '25e48130-0802-4cdf-82ab-c54800e509d5', -- Poutní místo Velehrad
  'd0493c6a-7c6f-4317-bb6a-6b51e8ddd9b3', -- Zámek Křtiny
  '53ec3ae9-d89a-49ff-84be-33dd153a9303', -- Devět křížů
  '2986cdcd-9bb2-46b8-a8de-b0e4f8047db6', -- Klášter Rosa Coeli
  'e272b2b6-d2e3-42a9-b699-e780353c81c6', -- Poutní místo Homol
  'c4a9e6fc-ca91-4fa5-b339-18ae2fc18a1f', -- Hrad Potštejn
  'd953f0c3-9b87-4000-9241-3bb80015ce2d', -- Zelená Hora
  'e7af8b1f-0715-4f95-ad6c-20a8cb3728f5', -- Zřícenina tvrze Melechov
  'e4ebbf48-0a76-43ef-ba00-a2a45f703342', -- Hrobka rodu Lobkowiczů
  'fac54e10-81a8-4323-b2b9-e4d602813ad0', -- Hazmburk
  '49d12850-d8cf-427c-8569-c42fbb303cb9', -- Novogotický templ
  '5a9edbe7-5b3c-42b1-8640-b04019859297', -- Vodní hrad Bašta s vyhlídkovým ochozem
  'ceea2845-e91b-4443-8e76-9edbaa677a62', -- Zřícenina kostela sv. Michala
  'bc1d69dd-383d-485f-a750-bd571c66030d', -- Kolonáda na Reistně
  'f90ecda6-5720-4538-acaf-356b59f3500b', -- Barfußweg Warte
  'bee11123-84fd-42c3-ac68-59a21849390f', -- Brána druidů
  'a9f56437-099b-4c9e-becd-b921c2e4f358', -- Zřícenina hradu Děvičky
  'ca19d353-2295-48a9-8f5c-b3e85b60fa95', -- Janův hrad
  'b8edca4c-1b8a-405a-bf71-d4d1629ddb7e', -- Minaret Lednice
  '3047ad71-9069-40fa-8dc8-6d45e455b4f1', -- Socha Radegasta
  '7741e227-412b-4b28-864b-b454361a8352', -- Zvonička Pustevny
  '35ecf283-9117-4ffc-92ed-a2aa67411f5e' -- Socha Radegasta
);
