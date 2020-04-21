-- ===============LICENSE_START=======================================================
-- Acumos Apache-2.0
-- ===================================================================================
-- Copyright (C) 2017-2018 AT&T Intellectual Property & Tech Mahindra. All rights reserved.
-- ===================================================================================
-- This Acumos software file is distributed by AT&T and Tech Mahindra
-- under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--      http://www.apache.org/licenses/LICENSE-2.0
--
-- This file is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- ===============LICENSE_END=========================================================

-- This script creates a database and two user entries for that database.
-- Replace CAPITALIZED TOKENS for other databases, users, passwords, etc.

drop database if exists %CDS%;
create database %CDS%;
create user '%CDS_USER%'@'localhost' identified by '%CDS_PASS%';
grant all on %CDS%.* to '%CDS_USER%'@'localhost';
create user '%CDS_USER%'@'%' identified by '%CDS_PASS%';
grant all on %CDS%.* to '%CDS_USER%'@'%';
flush privileges;

