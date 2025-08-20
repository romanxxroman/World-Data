
-- World Data: Core Schema (PostgreSQL)
-- Focus: strong provenance, time-bounded facts, and cross-linking to places & sources.
-- Note: Enables multi-ethnic identity, multiple names, uncertain dates, and confidence scores.

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- USERS & AUTH (application layer will enforce auth; store hashed passwords only)
CREATE TABLE IF NOT EXISTS app_user (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'user',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- VOCAB: Controlled terms for repeatable values (e.g., ethnicity labels, doc types)
CREATE TABLE IF NOT EXISTS vocabulary (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    scheme TEXT NOT NULL,      -- e.g., 'ethnicity', 'haplogroup_type', 'doc_type'
    code TEXT NOT NULL,
    label TEXT NOT NULL,
    UNIQUE (scheme, code)
);

-- PLACES: modern + historical with aliases for original names
CREATE TABLE IF NOT EXISTS place (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    canonical_name TEXT NOT NULL,
    type TEXT,                 -- settlement, region, kingdom, province, site
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    start_year INT,            -- known active interval, optional
    end_year INT,
    geojson JSONB,             -- optional polygon/shape
    notes TEXT
);

CREATE TABLE IF NOT EXISTS place_alias (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    place_id UUID NOT NULL REFERENCES place(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    language TEXT,             -- ISO code if known
    start_year INT,
    end_year INT
);

-- SOURCES: every assertion should point here
CREATE TABLE IF NOT EXISTS source (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    author TEXT,
    publisher TEXT,
    year INT,
    source_type TEXT,          -- census, registry, dna, oral_history, book, article, archive_record, image
    url TEXT,
    repository TEXT,           -- e.g., NARA, UK National Archives, French ANOM
    citation TEXT,             -- full citation string
    rights TEXT,               -- copyright / usage
    notes TEXT
);

-- DOCUMENTS & IMAGES
CREATE TABLE IF NOT EXISTS document (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_id UUID REFERENCES source(id) ON DELETE SET NULL,
    doc_type TEXT,             -- e.g., "US_1910_Census"
    original_filename TEXT,
    storage_path TEXT,         -- blob storage URI or relative path
    thumb_path TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    notes TEXT
);

CREATE TABLE IF NOT EXISTS person (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    canonical_given TEXT,
    canonical_surname TEXT,
    sex TEXT,                  -- as recorded; keep flexible
    birth_approx_year INT,
    death_approx_year INT,
    primary_ethnicity_code TEXT, -- optional default ethnicity code (link to vocabulary.scheme='ethnicity')
    notes TEXT
);

-- Multiple names over life with provenance
CREATE TABLE IF NOT EXISTS person_name (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    person_id UUID NOT NULL REFERENCES person(id) ON DELETE CASCADE,
    name_type TEXT,            -- birth, alias, married, slave_name, emancipated_name, nickname
    given TEXT,
    surname TEXT,
    language TEXT,
    start_year INT,
    end_year INT,
    source_id UUID REFERENCES source(id) ON DELETE SET NULL,
    confidence REAL CHECK (confidence >= 0 AND confidence <= 1)
);

-- Events with time-bounds and place (birth, marriage, migration, census appearance, adoption, emancipation, etc.)
CREATE TABLE IF NOT EXISTS event (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    person_id UUID REFERENCES person(id) ON DELETE CASCADE,
    event_type TEXT,
    place_id UUID REFERENCES place(id) ON DELETE SET NULL,
    date_text TEXT,            -- free-text if partial (e.g., 'Spring 1871'); parse later
    year INT,
    month INT,
    day INT,
    source_id UUID REFERENCES source(id) ON DELETE SET NULL,
    confidence REAL CHECK (confidence >= 0 AND confidence <= 1),
    notes TEXT
);

-- Person-to-person relationships (parent-child, spouse, sibling, adoptive, enslaver-enslaved, community ties)
CREATE TABLE IF NOT EXISTS relationship (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    person_id_a UUID NOT NULL REFERENCES person(id) ON DELETE CASCADE,
    person_id_b UUID NOT NULL REFERENCES person(id) ON DELETE CASCADE,
    rel_type TEXT,             -- parent_of, spouse_of, sibling_of, adoptive_parent_of, enslaver_of, guardian_of
    start_year INT,
    end_year INT,
    source_id UUID REFERENCES source(id) ON DELETE SET NULL,
    confidence REAL CHECK (confidence >= 0 AND confidence <= 1),
    notes TEXT
);

-- Genetics: store haplogroups & summary stats, not raw sensitive data
CREATE TABLE IF NOT EXISTS genetic_profile (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    person_id UUID NOT NULL REFERENCES person(id) ON DELETE CASCADE,
    profile_type TEXT,         -- mtDNA, Y-DNA, autosomal_summary
    haplogroup TEXT,
    percent_west_central_africa REAL,
    percent_west_africa REAL,
    percent_sahel REAL,
    percent_east_africa REAL,
    percent_sephardi_mizrahi REAL,
    percent_native_american REAL,
    percent_europe_west REAL,
    percent_europe_south REAL,
    percent_other REAL,
    lab TEXT,
    test_date DATE,
    source_id UUID REFERENCES source(id) ON DELETE SET NULL,
    notes TEXT
);

-- Assertions: any statement about a person/place/time with provenance
CREATE TABLE IF NOT EXISTS assertion (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    subject_type TEXT NOT NULL,  -- 'person','place','relationship','event'
    subject_id UUID NOT NULL,
    predicate TEXT NOT NULL,     -- 'born_in','aka','resided_at','occupation','ethnicity','surname_origin'
    object TEXT NOT NULL,        -- value or URI
    source_id UUID REFERENCES source(id) ON DELETE SET NULL,
    confidence REAL CHECK (confidence >= 0 AND confidence <= 1),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    notes TEXT
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_person_name ON person(canonical_surname, canonical_given);
CREATE INDEX IF NOT EXISTS idx_event_person ON event(person_id);
CREATE INDEX IF NOT EXISTS idx_assertion_subject ON assertion(subject_id);
