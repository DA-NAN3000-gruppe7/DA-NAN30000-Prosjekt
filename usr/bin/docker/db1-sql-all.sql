BEGIN TRANSACTION;
CREATE TABLE IF NOT EXISTS "Bruker" (
	"epostadresse"	TEXT,
	"passordhash"	TEXT,
	"fornavn"	TEXT,
	"etternavn"	TEXT,
	PRIMARY KEY("epostadresse")
);
CREATE TABLE IF NOT EXISTS "Dikt" (
	"diktID"	INTEGER,
	"dikt"	TEXT,
	"epostadresse"	TEXT,
	FOREIGN KEY("epostadresse") REFERENCES "Bruker"("epostadresse"),
	PRIMARY KEY("diktID")
);
CREATE TABLE IF NOT EXISTS "Sesjon" (
	"sesjonsID"	TEXT,
	"epostadresse"	TEXT,
	FOREIGN KEY("epostadresse") REFERENCES "Bruker"("epostadresse"),
	PRIMARY KEY("sesjonsID")
);
COMMIT;
