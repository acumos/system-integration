-- ========================================================================
-- Copyright (c) 2019-2020 AT&T Intellectual Property. All rights reserved.
-- ========================================================================
-- Unless otherwise specified, all software contained herein is licensed
-- under the Apache License, Version 2.0 (the "License");
-- you may not use this software except in compliance with the License.
-- You may obtain a copy of the License at
--
--             http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- ============LICENSE_END=================================================

\connect lumdb lumdb;
-- \conninfo;
SELECT version();

DROP TABLE IF EXISTS "snapshot";
DROP TABLE IF EXISTS "assetUsageHistory";
DROP TABLE IF EXISTS "includedAssetUsage";
DROP TABLE IF EXISTS "assetUsage";
DROP TABLE IF EXISTS "usageMetrics";
DROP TABLE IF EXISTS "assetUsageReq";
DROP TABLE IF EXISTS "rightToUse";
DROP TABLE IF EXISTS "assetUsageAgreement";
DROP TABLE IF EXISTS "swidTag";
DROP TABLE IF EXISTS "licenseProfile";
DROP TABLE IF EXISTS "swMgtSystem";
DROP TABLE IF EXISTS "lumInfo";


CREATE TABLE "lumInfo" (
    "lumSystem"     TEXT NOT NULL PRIMARY KEY DEFAULT 'LUM',
    "lumVersion"    TEXT NOT NULL,
    --housekeeping--
    "creator"       TEXT NOT NULL DEFAULT USER,
    "created"       TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    "modifier"      TEXT NOT NULL DEFAULT USER,
    "modified"      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE "lumInfo" IS 'contains info about LUM';
COMMENT ON COLUMN "lumInfo"."lumSystem" IS 'LUM';
COMMENT ON COLUMN "lumInfo"."lumVersion" IS 'LUM-server version';
COMMENT ON COLUMN "lumInfo"."creator" IS 'userId of the creator';
COMMENT ON COLUMN "lumInfo"."created" IS 'when the record was created';
COMMENT ON COLUMN "lumInfo"."modifier" IS 'userId of the modifier';
COMMENT ON COLUMN "lumInfo"."modified" IS 'when the record was updated';

-- software management system --

CREATE TABLE "swMgtSystem" (
    "swMgtSystemId"     TEXT NOT NULL PRIMARY KEY,
    --housekeeping--
    "creator"           TEXT NOT NULL DEFAULT USER,
    "created"           TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    "modifier"          TEXT NOT NULL DEFAULT USER,
    "modified"          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE "swMgtSystem" IS 'contains all settings per software management system like Acumos';
COMMENT ON COLUMN "swMgtSystem"."swMgtSystemId" IS 'like Acumos';
COMMENT ON COLUMN "swMgtSystem"."creator" IS 'userId of the creator';
COMMENT ON COLUMN "swMgtSystem"."created" IS 'when the record was created';
COMMENT ON COLUMN "swMgtSystem"."modifier" IS 'userId of the modifier';
COMMENT ON COLUMN "swMgtSystem"."modified" IS 'when the record was updated';

-- License Inventory --

CREATE TABLE "licenseProfile" (
    "licenseProfileId"          UUID NOT NULL PRIMARY KEY,
    "softwareLicensorId"        TEXT NOT NULL,
    "licenseProfile"            JSONB NULL,
    "isRtuRequired"             BOOLEAN NOT NULL DEFAULT TRUE,
    "licenseTxt"                TEXT NULL,
    "licenseName"               TEXT NULL,
    "licenseDescription"        TEXT NULL,
    "licenseNotes"              TEXT NULL,
    --housekeeping--
    "licenseProfileRevision"    INTEGER NOT NULL DEFAULT 1,
    "licenseProfileActive"      BOOLEAN NOT NULL DEFAULT TRUE,
    "creator"                   TEXT NOT NULL DEFAULT USER,
    "created"                   TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    "modifier"                  TEXT NOT NULL DEFAULT USER,
    "modified"                  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    "closer"                    TEXT NULL,
    "closed"                    TIMESTAMP WITH TIME ZONE NULL,
    "closureReason"             TEXT NULL
);
COMMENT ON TABLE "licenseProfile" IS 'terms and conditions define the rights for managing the usage of the software asset';
COMMENT ON COLUMN "licenseProfile"."licenseProfileId" IS 'identifier of the license - can be shared between multiple swTagId';
COMMENT ON COLUMN "licenseProfile"."softwareLicensorId" IS 'identifier of the supplier or owner of the software who provides the license profile and the right-to-use';
COMMENT ON COLUMN "licenseProfile"."licenseProfile" IS 'full body of the license profile';
COMMENT ON COLUMN "licenseProfile"."isRtuRequired" IS 'whether requires the right-to-use for usage, when false goes directly to usageMetrics';
COMMENT ON COLUMN "licenseProfile"."licenseTxt" IS 'license.txt - humanly readable terms and conditions for the licenseProfile';
COMMENT ON COLUMN "licenseProfile"."licenseName" IS 'name of the license in free text';
COMMENT ON COLUMN "licenseProfile"."licenseDescription" IS 'desciption of the license in free text';
COMMENT ON COLUMN "licenseProfile"."licenseNotes" IS 'any textual notes';
COMMENT ON COLUMN "licenseProfile"."licenseProfileRevision" IS '1,2,3,... revision of the license - updates are allowed - auto-incremented by LUM';
COMMENT ON COLUMN "licenseProfile"."licenseProfileActive" IS 'whether the license profile is currently active - not closed and not expired and not revoked';
COMMENT ON COLUMN "licenseProfile"."creator" IS 'userId of the creator';
COMMENT ON COLUMN "licenseProfile"."created" IS 'when the record was created';
COMMENT ON COLUMN "licenseProfile"."modifier" IS 'userId of the modifier';
COMMENT ON COLUMN "licenseProfile"."modified" IS 'when the record was updated';
COMMENT ON COLUMN "licenseProfile"."closer" IS 'userId of the closer';
COMMENT ON COLUMN "licenseProfile"."closed" IS 'when the record was revoked-closed';
COMMENT ON COLUMN "licenseProfile"."closureReason" IS 'reason for the closure - revoked, expired, etc.';


CREATE TABLE "swidTag" (
    "swTagId"               TEXT NOT NULL PRIMARY KEY,
    "swPersistentId"        UUID NOT NULL,
    "swVersion"             TEXT NOT NULL,
    "swVersionComparable"   TEXT NULL,
    "licenseProfileId"      UUID NOT NULL REFERENCES "licenseProfile" ("licenseProfileId"),
    "softwareLicensorId"    TEXT NOT NULL,
    "swCategory"            TEXT NULL,
    "swCatalogs"            JSONB NULL,
    "swCreators"            TEXT[] NULL,
    "swProductName"         TEXT NULL,
    "swidTagDetails"        JSONB NULL,
    --housekeeping--
    "swidTagRevision"       INTEGER NOT NULL DEFAULT 1,
    "swidTagActive"         BOOLEAN NOT NULL DEFAULT TRUE,
    "creator"               TEXT NOT NULL DEFAULT USER,
    "created"               TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    "modifier"              TEXT NOT NULL DEFAULT USER,
    "modified"              TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    "closer"                TEXT NULL,
    "closed"                TIMESTAMP WITH TIME ZONE NULL,
    "closureReason"         TEXT NULL
);
CREATE INDEX "idxSwidTagPersistent" ON "swidTag" ("swPersistentId", "swVersion");
CREATE INDEX "idxSwidTagLicenseProfile" ON "swidTag" ("licenseProfileId");
CREATE INDEX "idxSwidTagsoftwareLicensor" ON "swidTag" ("softwareLicensorId");

COMMENT ON TABLE "swidTag" IS 'software identification tag that is inspired by ISO/IEC 19770-2';
COMMENT ON COLUMN "swidTag"."swTagId" IS 'GUID+version -- identifier of the software up to specific version - revisionId in Acumos\n possible format: <swPersistentId>_<swVersion>. Example: "c0de3e70-e815-461f-9734-a239c450bf77_7.5.3.123-t1"';
COMMENT ON COLUMN "swidTag"."swPersistentId" IS 'versionless product-id that persiste between the version of the software. Example: "c0de3e70-e815-461f-9734-a239c450bf77"';
COMMENT ON COLUMN "swidTag"."swVersion" IS 'version of the software semver like "7.5.3.123-t1"';
COMMENT ON COLUMN "swidTag"."swVersionComparable" IS 'comparable value for the version of the software. Example for semver in comparable format: "00000007.00000005.00000003.00000123-t00000001"';
COMMENT ON COLUMN "swidTag"."licenseProfileId" IS 'identifier of the license profile attached to the software. FK to licenseProfile';
COMMENT ON COLUMN "swidTag"."softwareLicensorId" IS 'identifier of the supplier or owner of the software who provides the license profile and the right-to-use';
COMMENT ON COLUMN "swidTag"."swCategory" IS 'image processing, software, image, video, data. - used for matching to the right-to-use';
COMMENT ON COLUMN "swidTag"."swCatalogs" IS 'array of catalog info the software is stored in Acumos. [{"swCatalogId": "", -- uid for the catalog identifier\n "swCatalogType":"" -- restricted, company-wide, public, etc.}]';
COMMENT ON COLUMN "swidTag"."swCreators" IS 'collection of userId values of the creators for swidTag = superusers of the software';
COMMENT ON COLUMN "swidTag"."swProductName" IS 'product name like Windows';
COMMENT ON COLUMN "swidTag"."swidTagDetails" IS 'any other details: edition TEXT -- like Pro, Dev, Enterprise, Ultimate,\n revision TEXT -- build or revision number,\n marketVersion TEXT -- might differ from swVersion,\n patch BOOL -- indication that this is a patch,\n productUrl TEXT -- url to find more info at the licensor site';
COMMENT ON COLUMN "swidTag"."swidTagRevision" IS '1,2,3,... revision of the swidTag - updates are allowed - auto-incremented by LUM';
COMMENT ON COLUMN "swidTag"."swidTagActive" IS 'whether the record is not revoked-closed';
COMMENT ON COLUMN "swidTag"."creator" IS 'userId of the creator';
COMMENT ON COLUMN "swidTag"."created" IS 'when the record was created';
COMMENT ON COLUMN "swidTag"."modifier" IS 'userId of the modifier';
COMMENT ON COLUMN "swidTag"."modified" IS 'when the record was updated';
COMMENT ON COLUMN "swidTag"."closer" IS 'userId of the closer';
COMMENT ON COLUMN "swidTag"."closed" IS 'when the record was revoked-closed';
COMMENT ON COLUMN "swidTag"."closureReason" IS 'reason for the closure - revoked, expired, etc.';

-- Entitlement --
CREATE TABLE "assetUsageAgreement" (
    "softwareLicensorId"            TEXT NOT NULL,
    "assetUsageAgreementId"         TEXT NOT NULL,
    --agreements details--
    "agreement"                     JSONB NOT NULL,
    "agreementRestriction"          JSONB NULL,
    "groomedAgreement"              JSONB NULL,
    --housekeeping--
    "assetUsageAgreementRevision"   INTEGER NOT NULL DEFAULT 1,
    "assetUsageAgreementActive"     BOOLEAN NOT NULL DEFAULT TRUE,
    "creator"                       TEXT NOT NULL DEFAULT USER,
    "created"                       TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    "modifier"                      TEXT NOT NULL DEFAULT USER,
    "modified"                      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    "closer"                        TEXT NULL,
    "closed"                        TIMESTAMP WITH TIME ZONE NULL,
    "closureReason"                 TEXT NULL,
    PRIMARY KEY ("softwareLicensorId", "assetUsageAgreementId")
);

COMMENT ON TABLE "assetUsageAgreement" IS 'collection of purchased rights-to-use/permissions - ODRL - Agreement https://www.w3.org/TR/odrl-model/#policy-agreement';
COMMENT ON COLUMN "assetUsageAgreement"."assetUsageAgreementId" IS 'UID key to assetUsageAgreement in IRI or URI format. possible format: "http://software-licensor/<softwareLicensorId>/agreement/<agreement-uuid>"';
COMMENT ON COLUMN "assetUsageAgreement"."softwareLicensorId" IS 'identifier of the supplier or owner of the software who provides the license profile and the right-to-use';
COMMENT ON COLUMN "assetUsageAgreement"."agreement" IS 'full body of ODRL agreement received from supplier';
COMMENT ON COLUMN "assetUsageAgreement"."agreementRestriction" IS 'full body of ODRL agreement restriction from the subscriber company';
COMMENT ON COLUMN "assetUsageAgreement"."groomedAgreement" IS 'groomed full body of ODRL agreement with restriction already applied';
COMMENT ON COLUMN "assetUsageAgreement"."assetUsageAgreementRevision" IS '1,2,3,... auto-incremented by LUM - revision - updates are allowed';
COMMENT ON COLUMN "assetUsageAgreement"."assetUsageAgreementActive" IS 'whether the record is not revoked-closed';
COMMENT ON COLUMN "assetUsageAgreement"."creator" IS 'userId of the creator';
COMMENT ON COLUMN "assetUsageAgreement"."created" IS 'when the record was created';
COMMENT ON COLUMN "assetUsageAgreement"."modifier" IS 'userId of the modifier';
COMMENT ON COLUMN "assetUsageAgreement"."modified" IS 'when the record was updated';
COMMENT ON COLUMN "assetUsageAgreement"."closer" IS 'userId of the closer';
COMMENT ON COLUMN "assetUsageAgreement"."closed" IS 'when the record was revoked-closed';
COMMENT ON COLUMN "assetUsageAgreement"."closureReason" IS 'reason for the closure - revoked, expired, etc.';

CREATE TABLE "rightToUse" (
    "assetUsageRuleId"          TEXT NOT NULL PRIMARY KEY,
    "softwareLicensorId"        TEXT NOT NULL,
    "assetUsageAgreementId"     TEXT NOT NULL,
    "rightToUseId"              TEXT NOT NULL,
    "assetUsageRuleType"        TEXT NOT NULL DEFAULT 'permission',
    "actions"                   TEXT[] NULL,
    "targetRefinement"          JSONB NULL,
    "assigneeRefinement"        JSONB NULL,
    "usageConstraints"          JSONB NULL,
    "consumedConstraints"       JSONB NULL,
    "licenseKeys"               TEXT[] NULL,
    --timeframe extracted from constraints--
    "isPerpetual"               BOOLEAN NOT NULL DEFAULT FALSE,
    "enableOn"                  DATE NULL,
    "expireOn"                  DATE NULL,
    "goodFor"                   INTERVAL NULL,
    --timeframe and usage metrics--
    "assigneeMetrics"           JSONB NOT NULL,
    "usageStartReqId"           UUID NULL,
    "usageStarted"              TIMESTAMP WITH TIME ZONE NULL,
    "usageEnds"                 TIMESTAMP WITH TIME ZONE NULL,
    --housekeeping--
    "rightToUseRevision"        INTEGER NOT NULL DEFAULT 1,
    "metricsRevision"           INTEGER NOT NULL DEFAULT 0,
    "rightToUseActive"          BOOLEAN NOT NULL DEFAULT TRUE,
    "creator"                   TEXT NOT NULL DEFAULT USER,
    "created"                   TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    "modifier"                  TEXT NOT NULL DEFAULT USER,
    "modified"                  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    "closer"                    TEXT NULL,
    "closed"                    TIMESTAMP WITH TIME ZONE NULL,
    "closureReason"             TEXT NULL,
    "metricsModifierReqId"      UUID NULL,
    "metricsModified"           TIMESTAMP WITH TIME ZONE NULL,
    FOREIGN KEY ("softwareLicensorId", "assetUsageAgreementId") REFERENCES "assetUsageAgreement" ("softwareLicensorId", "assetUsageAgreementId")
);
CREATE UNIQUE INDEX "uidxRightToUse" ON "rightToUse" ("softwareLicensorId", "assetUsageAgreementId", "rightToUseId");

COMMENT ON TABLE "rightToUse" IS 'in ODRL this is a permission rule for matching and usage rights for specific software assets';
COMMENT ON COLUMN "rightToUse"."assetUsageRuleId" IS 'uuid of the rule';
COMMENT ON COLUMN "rightToUse"."softwareLicensorId" IS 'identifier of the supplier or owner of the software who provides the license profile and the right-to-use';
COMMENT ON COLUMN "rightToUse"."assetUsageAgreementId" IS 'identifier of the parent assetUsageAgreement';
COMMENT ON COLUMN "rightToUse"."rightToUseId" IS 'UID key to rightToUse in IRI or URI format. possible format: "http://software-licensor/<softwareLicensorId>/permission/<permission-uuid>"';
COMMENT ON COLUMN "rightToUse"."assetUsageRuleType" IS 'ENUM {permission, prohibition} -- see ODRL';
COMMENT ON COLUMN "rightToUse"."actions" IS '[action] - list of action values for the rule (permission.action)';
COMMENT ON COLUMN "rightToUse"."targetRefinement" IS 'groomed target refinement with restriction already applied';
COMMENT ON COLUMN "rightToUse"."assigneeRefinement" IS 'groomed assignee refinement with restriction already applied';
COMMENT ON COLUMN "rightToUse"."usageConstraints" IS 'groomed usageConstraints with restriction already applied';
COMMENT ON COLUMN "rightToUse"."consumedConstraints" IS 'constraints that were consumed by grooming - for debugging';
COMMENT ON COLUMN "rightToUse"."licenseKeys" IS '[licenseKey] - list of license-keys provided by supplier are consumed by the software to unlock the functionality';
COMMENT ON COLUMN "rightToUse"."isPerpetual" IS 'extracted from usageConstraints: never expires if true';
COMMENT ON COLUMN "rightToUse"."enableOn" IS 'when the asset-usage by assetUsageAgreement becomes enabled GMT';
COMMENT ON COLUMN "rightToUse"."expireOn" IS 'when the asset-usage by assetUsageAgreement expires GMT';
COMMENT ON COLUMN "rightToUse"."goodFor" IS 'timeperiod in seconds for entitled asset-usage. Example: 30 days == 2592000 secs';
COMMENT ON COLUMN "rightToUse"."assigneeMetrics" IS 'metrics for assignee - list of unique users {users: ["alex", "justin"]}';
COMMENT ON COLUMN "rightToUse"."usageStartReqId" IS 'identifier of request that started the usage of the rightToUse';
COMMENT ON COLUMN "rightToUse"."usageStarted" IS 'populated on first start of the usage';
COMMENT ON COLUMN "rightToUse"."usageEnds" IS 'usageStarted + goodFor';
COMMENT ON COLUMN "rightToUse"."rightToUseRevision" IS '1,2,3,... auto-incremented by LUM - revision - updates are allowed';
COMMENT ON COLUMN "rightToUse"."metricsRevision" IS '1,2,3,... auto-incremented by LUM - revision of changing the value of the metrics';
COMMENT ON COLUMN "rightToUse"."rightToUseActive" IS 'whether rightToUse is enabled and not revoked-closed or expired';
COMMENT ON COLUMN "rightToUse"."creator" IS 'userId of the creator';
COMMENT ON COLUMN "rightToUse"."created" IS 'when the record was created';
COMMENT ON COLUMN "rightToUse"."modifier" IS 'userId of the modifier';
COMMENT ON COLUMN "rightToUse"."modified" IS 'when the record was updated';
COMMENT ON COLUMN "rightToUse"."closer" IS 'userId of the closer';
COMMENT ON COLUMN "rightToUse"."closed" IS 'when the record was revoked-closed';
COMMENT ON COLUMN "rightToUse"."closureReason" IS 'reason for the closure - revoked, expired, etc.';
COMMENT ON COLUMN "rightToUse"."metricsModifierReqId" IS 'identifier of request that modified the metrics';
COMMENT ON COLUMN "rightToUse"."metricsModified" IS 'when the metrics was updated';

-- AUM --
CREATE TABLE "assetUsageReq" (
    "assetUsageReqId"           UUID NOT NULL PRIMARY KEY,
    "action"                    TEXT NOT NULL,
    "assetUsageType"            TEXT NOT NULL DEFAULT 'assetUsage',
    "requestHttp"               JSON NOT NULL,
    "request"                   JSON NOT NULL,
    "responseHttpCode"          INTEGER NULL,
    "response"                  JSON NULL,
    "usageEntitled"             BOOLEAN NULL,
    --housekeeping--
    "userId"                    TEXT NULL,
    "status"                    TEXT NOT NULL,
    "requestStarted"            TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    "requestDone"               BOOLEAN NOT NULL DEFAULT FALSE,
    "responseSent"              TIMESTAMP WITH TIME ZONE NULL
);

COMMENT ON TABLE "assetUsageReq" IS 'request received by LUM for granting the entitlement for the asset usage or record the event. can be more than one asset when other assets are included';
COMMENT ON COLUMN "assetUsageReq"."assetUsageReqId" IS 'identifier of the assetUsageReq - identifier of request that inserted the assetUsageHistory';
COMMENT ON COLUMN "assetUsageReq"."action" IS 'download, deploy, execute, ...';
COMMENT ON COLUMN "assetUsageReq"."assetUsageType" IS 'ENUM {assetUsage, assetUsageEvent}';
COMMENT ON COLUMN "assetUsageReq"."requestHttp" IS 'http method+urlPath part of the request. {> method TEXT -- put, delete, post\n path TEXT -- path in url like "/asset-usage/{assetUsageId}"\n ips TEXT[] -- ip-addresses of the http client, ...}';
COMMENT ON COLUMN "assetUsageReq"."request" IS 'full copy of request message - see API for more details';
COMMENT ON COLUMN "assetUsageReq"."responseHttpCode" IS '200 for success, 224 for revoked, 402 for denial';
COMMENT ON COLUMN "assetUsageReq"."response" IS 'usage assetUsageAgreement result full copy of response message - see API for more details';
COMMENT ON COLUMN "assetUsageReq"."usageEntitled" IS 'whether the action on the request has been entitled (true) or not (false) by LUM';
COMMENT ON COLUMN "assetUsageReq"."userId" IS 'userId on the request';
COMMENT ON COLUMN "assetUsageReq"."status" IS 'ENUM {entitled, denied, eventRecorded, ...}';
COMMENT ON COLUMN "assetUsageReq"."requestStarted" IS 'when the request processing started = this record is created';
COMMENT ON COLUMN "assetUsageReq"."requestDone" IS 'true on sending the response = this record is updated';
COMMENT ON COLUMN "assetUsageReq"."responseSent" IS 'when the response was sent = this record is updated';

-- AUM - usageMetrics --
CREATE TABLE "usageMetrics" (
    "usageMetricsId"        TEXT NOT NULL,
    "action"                TEXT NOT NULL,
    "usageType"             TEXT NOT NULL,
    "swTagId"               TEXT NULL,
    "assetUsageRuleId"      TEXT NULL,
    --usage metrics--
    "metrics"               JSONB NOT NULL,
    --housekeeping--
    "usageMetricsRevision"  INTEGER NOT NULL DEFAULT 1,
    "creator"               TEXT NOT NULL DEFAULT USER,
    "created"               TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    "creatorRequestId"      UUID NULL,
    "modifier"              TEXT NOT NULL DEFAULT USER,
    "modified"              TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    "modifierRequestId"     UUID NULL,
    PRIMARY KEY ("usageMetricsId", "action", "usageType")
);
COMMENT ON TABLE "usageMetrics" IS 'usage per single RTU+action on each asset separately.\n contains constraints with status-metrics onRule and onRuleStandalone.\n for usageType == rightToUse -> usageMetricsId == rightToUse.assetUsageRuleId FK to rightToUse\n for usageType == bySwCreator -> usageMetricsId == swidTag.swTagId FK to swidTag\n for usageType == freeToUse -> usageMetricsId == swidTag.swTagId FK to swidTag';
COMMENT ON COLUMN "usageMetrics"."usageMetricsId" IS 'identifier of the usageMetrics - for usageType == rightToUse -> usageMetricsId == rightToUse.assetUsageRuleId FK to rightToUse.\n for usageType == bySwCreator -> usageMetricsId == swidTag.swTagId FK to swidTag.\n for usageType == freeToUse -> usageMetricsId == swidTag.swTagId FK to swidTag';
COMMENT ON COLUMN "usageMetrics"."action" IS 'download, deploy, execute, ...';
COMMENT ON COLUMN "usageMetrics"."usageType" IS 'ENUM {rightToUse, bySwCreator, freeToUse, assetUsageEvent} -- how the usageMetrics is created';
COMMENT ON COLUMN "usageMetrics"."swTagId" IS 'GUID+version -- identifier of the software up to specific version';
COMMENT ON COLUMN "usageMetrics"."assetUsageRuleId" IS 'identifier of the rightToUse for usageType=rightToUse';
COMMENT ON COLUMN "usageMetrics"."metrics" IS 'metrics - count of action calls etc. {count:3, users:["alex", "justin"]}';
COMMENT ON COLUMN "usageMetrics"."usageMetricsRevision" IS '1,2,3,... revision of the metrics';
COMMENT ON COLUMN "usageMetrics"."creator" IS 'userId of the creator';
COMMENT ON COLUMN "usageMetrics"."created" IS 'when the record was created';
COMMENT ON COLUMN "usageMetrics"."creatorRequestId" IS 'identifier of request that created the metrics';
COMMENT ON COLUMN "usageMetrics"."modifier" IS 'userId of the modifier';
COMMENT ON COLUMN "usageMetrics"."modified" IS 'when the record was updated';
COMMENT ON COLUMN "usageMetrics"."modifierRequestId" IS 'identifier of request that modified the metrics';

-- AUT --
CREATE TABLE "assetUsage" (
    "assetUsageId"                  TEXT NOT NULL PRIMARY KEY,
    "isIncludedAsset"               BOOLEAN NOT NULL DEFAULT FALSE,
    --tails of history--
    "assetUsageSeqTail"             INTEGER NOT NULL DEFAULT 0,
    "assetUsageSeqTailEntitled"     INTEGER NULL,
    "assetUsageSeqTailEntitlement"  INTEGER NULL,
    "assetUsageSeqTailEvent"        INTEGER NULL,
    --housekeeping--
    "creator"                       TEXT NOT NULL DEFAULT USER,
    "created"                       TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    "modifier"                      TEXT NOT NULL DEFAULT USER,
    "modified"                      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE "assetUsage" IS 'usage of the software asset by users';
COMMENT ON COLUMN "assetUsage"."assetUsageId" IS 'identifier of the assetUsage - FK1 to assetUsageHistory';
COMMENT ON COLUMN "assetUsage"."isIncludedAsset" IS 'included asset (true), master asset (false)';
COMMENT ON COLUMN "assetUsage"."assetUsageSeqTail" IS 'sequential number 1,2,3,... - auto-incremented by LUM - FK2 to tail record on assetUsageHistory';
COMMENT ON COLUMN "assetUsage"."assetUsageSeqTailEntitled" IS 'FK2 to assetUsageHistory for last successful entitlement in assetUsageHistory';
COMMENT ON COLUMN "assetUsage"."assetUsageSeqTailEntitlement" IS 'FK2 to assetUsageHistory for last entitlement';
COMMENT ON COLUMN "assetUsage"."assetUsageSeqTailEvent" IS 'FK2 to assetUsageHistory for last event';
COMMENT ON COLUMN "assetUsage"."creator" IS 'userId of the creator';
COMMENT ON COLUMN "assetUsage"."created" IS 'when the record was created';
COMMENT ON COLUMN "assetUsage"."modifier" IS 'userId of the modifier';
COMMENT ON COLUMN "assetUsage"."modified" IS 'when the record was updated';

CREATE TABLE "includedAssetUsage" (
    "assetUsageId"          TEXT NOT NULL REFERENCES "assetUsage" ("assetUsageId"),
    "includedAssetUsageId"  TEXT NOT NULL REFERENCES "assetUsage" ("assetUsageId"),
    --housekeeping--
    "creator"               TEXT NOT NULL DEFAULT USER,
    "created"               TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    "creatorRequestId"      UUID NULL,
    PRIMARY KEY ("assetUsageId", "includedAssetUsageId")
);
CREATE UNIQUE INDEX "uidxIncludedAssetUsage" ON "includedAssetUsage" ("includedAssetUsageId", "assetUsageId");

COMMENT ON TABLE "includedAssetUsage" IS 'when software piece is either copied-included or composed of other software pieces';
COMMENT ON COLUMN "includedAssetUsage"."assetUsageId" IS 'identifier of the assetUsage';
COMMENT ON COLUMN "includedAssetUsage"."includedAssetUsageId" IS 'identifier of the assetUsage for the included asset';
COMMENT ON COLUMN "includedAssetUsage"."creator" IS 'userId of the creator';
COMMENT ON COLUMN "includedAssetUsage"."created" IS 'when action happened - record created';
COMMENT ON COLUMN "includedAssetUsage"."creatorRequestId" IS 'identifier of request that created the record';

CREATE TABLE "assetUsageHistory" (
    "assetUsageId"                  TEXT NOT NULL REFERENCES "assetUsage" ("assetUsageId"),
    "assetUsageSeq"                 INTEGER NOT NULL DEFAULT 1,
    "assetUsageType"                TEXT NOT NULL DEFAULT 'assetUsage',
    "assetUsageReqId"               UUID NOT NULL REFERENCES "assetUsageReq" ("assetUsageReqId"),
    "action"                        TEXT NOT NULL,
    "softwareLicensorId"            TEXT NULL,
    "swMgtSystemId"                 TEXT NULL,
    "swMgtSystemInstanceId"         TEXT NULL,
    "swMgtSystemComponent"          TEXT NULL,
    "swTagId"                       TEXT NULL,
    "swidTagRevision"               INTEGER NULL,
    "licenseProfileId"              UUID NULL,
    "licenseProfileRevision"        INTEGER NULL,
    "isRtuRequired"                 BOOLEAN NULL,
    "assetUsageRuleId"              TEXT NULL,
    "rightToUseRevision"            INTEGER NULL,
    "assetUsageAgreementId"         TEXT NULL,
    "assetUsageAgreementRevision"   INTEGER NULL,
    "usageMetricsId"                TEXT NULL,
    "metrics"                       JSONB NULL,
    "assigneeMetrics"               JSONB NULL,

    --results--
    "usageEntitled"                 BOOLEAN NULL,
    "isUsedBySwCreator"             BOOLEAN NULL,
    "licenseKeys"                   TEXT[] NULL,
    "assetUsageDenialSummary"       TEXT NULL,
    "assetUsageDenial"              JSON NULL,
    --housekeeping--
    "creator"                       TEXT NOT NULL DEFAULT USER,
    "created"                       TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    PRIMARY KEY ("assetUsageId", "assetUsageSeq")
);
CREATE INDEX "idxAssetUsageHistorySoftwareLicensor" ON "assetUsageHistory" ("softwareLicensorId");

COMMENT ON TABLE "assetUsageHistory" IS 'history of the usage of the software asset. can only insert - never update or delete to this table';
COMMENT ON COLUMN "assetUsageHistory"."assetUsageId" IS 'identifier of the assetUsage';
COMMENT ON COLUMN "assetUsageHistory"."assetUsageSeq" IS 'sequential number 1,2,3,... - auto-incremented by LUM';
COMMENT ON COLUMN "assetUsageHistory"."assetUsageType" IS 'ENUM {assetUsage, assetUsageEvent}';
COMMENT ON COLUMN "assetUsageHistory"."assetUsageReqId" IS 'identifier of the assetUsageReq - identifier of request that inserted the assetUsageHistory';
COMMENT ON COLUMN "assetUsageHistory"."action" IS 'download, publish, execute, monitor, ...';
COMMENT ON COLUMN "assetUsageHistory"."softwareLicensorId" IS 'identifier of the supplier or owner of the software who provides the license profile and the right-to-use';
COMMENT ON COLUMN "assetUsageHistory"."swMgtSystemId" IS 'like Acumos';
COMMENT ON COLUMN "assetUsageHistory"."swMgtSystemInstanceId" IS 'system instance id that manages the software pieces and sent the request - like "Acumos#22"';
COMMENT ON COLUMN "assetUsageHistory"."swMgtSystemComponent" IS 'component inside the system that sent the request like "model-runner"';
COMMENT ON COLUMN "assetUsageHistory"."swTagId" IS 'GUID+version -- identifier of the software up to specific version';
COMMENT ON COLUMN "assetUsageHistory"."swidTagRevision" IS '1,2,3,... revision of the swidTag - updates are allowed - auto-incremented by LUM';
COMMENT ON COLUMN "assetUsageHistory"."licenseProfileId" IS 'identifier of the license profile attached to the software';
COMMENT ON COLUMN "assetUsageHistory"."licenseProfileRevision" IS '1,2,3,... revision of the license - updates are allowed - auto-incremented by LUM';
COMMENT ON COLUMN "assetUsageHistory"."isRtuRequired" IS 'whether requires the right-to-use for usage';
COMMENT ON COLUMN "assetUsageHistory"."assetUsageRuleId" IS 'identifier of the rightToUse for usageType=rightToUse';
COMMENT ON COLUMN "assetUsageHistory"."rightToUseRevision" IS '1,2,3,... revision of rightToUse';
COMMENT ON COLUMN "assetUsageHistory"."assetUsageAgreementId" IS 'FK to assetUsageAgreement';
COMMENT ON COLUMN "assetUsageHistory"."assetUsageAgreementRevision" IS '1,2,3,... revision of assetUsageAgreement';
COMMENT ON COLUMN "assetUsageHistory"."usageMetricsId" IS 'identifier of the usageMetrics';
COMMENT ON COLUMN "assetUsageHistory"."metrics" IS 'usage metrics used for entitlement';
COMMENT ON COLUMN "assetUsageHistory"."assigneeMetrics" IS 'assignee metrics used for entitlement';
COMMENT ON COLUMN "assetUsageHistory"."usageEntitled" IS 'whether the asset-usage entitled (true) or not (false)';
COMMENT ON COLUMN "assetUsageHistory"."isUsedBySwCreator" IS 'whether the userId listed in swCreators of the software';
COMMENT ON COLUMN "assetUsageHistory"."licenseKeys" IS '[licenseKey] - copied from usageMetrics - list of license-keys provided by supplier are consumed by the software to unlock the functionality';
COMMENT ON COLUMN "assetUsageHistory"."assetUsageDenialSummary" IS 'human readable summary for denial of the asset-usage';
COMMENT ON COLUMN "assetUsageHistory"."assetUsageDenial" IS 'denials of the usage of the software asset - see API';
COMMENT ON COLUMN "assetUsageHistory"."creator" IS 'userId of the record creator';
COMMENT ON COLUMN "assetUsageHistory"."created" IS 'when action happened - record created';

-- snapshot --
CREATE TABLE "snapshot" (
    "softwareLicensorId"    TEXT NOT NULL,
    "snapshotType"          TEXT NOT NULL,
    "snapshotKey"           TEXT NOT NULL,
    "snapshotRevision"      INTEGER NOT NULL,
    "snapshotBody"          JSON NOT NULL,
    --housekeeping--
    "creator"               TEXT NOT NULL DEFAULT USER,
    "created"               TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    "requestId"             UUID NULL,
    "txStep"                TEXT NULL,
    PRIMARY KEY ("softwareLicensorId", "snapshotType", "snapshotKey", "snapshotRevision")
);

COMMENT ON TABLE "snapshot" IS 'historical snapshots of any data';
COMMENT ON COLUMN "snapshot"."softwareLicensorId" IS 'identifier of the supplier or owner of the software who provides the license profile and the right-to-use';
COMMENT ON COLUMN "snapshot"."snapshotType" IS 'ENUM {licenseProfile, swidTag, assetUsageAgreement, rightToUse}';
COMMENT ON COLUMN "snapshot"."snapshotKey" IS 'PK to the source table like swTagId';
COMMENT ON COLUMN "snapshot"."snapshotRevision" IS 'revision field on the source table like swidTagRevision';
COMMENT ON COLUMN "snapshot"."snapshotBody" IS 'copy of the full record from source table';
COMMENT ON COLUMN "snapshot"."creator" IS 'userId of the creator';
COMMENT ON COLUMN "snapshot"."created" IS 'when snapshot happened - record created';
COMMENT ON COLUMN "snapshot"."requestId" IS 'uuid of the request that recorded the snapshot';
COMMENT ON COLUMN "snapshot"."txStep" IS 'transaction step that recorded the snapshot';
-- end --