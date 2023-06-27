----- generating table for data importing, the dataset is with multiple bad lines and varing length
----- The dataset used here is upon request
CREATE TABLE public.ARTICLE
(
    "A" varchar(100),"B" varchar(100),"C" varchar(100),"D" varchar(100),
	"E" varchar,"F" varchar,"G" varchar,"H" varchar,"I" varchar,"J" varchar,
	"K" varchar,"L" varchar,"M" varchar,"N" varchar,"O" varchar,"P" varchar,
	"Q" varchar,"R" varchar,"S" varchar,"T" varchar,"U" varchar,"V" varchar,
	"W" varchar,"X" varchar,"Y" varchar,"Z" varchar
);
-- data should be imported with delimiter = ;, leave Quote, Escape, 
-- Null string empty, header = Null

--- extracting proper username
-- firts, find out the bad lines with weird username
SELECT * FROM ARTICLE WHERE "A" !~ '^[a-zA-Z0-9]+\s\(.*\)$';

SELECT DISTINCT "A", substring("A" FROM '^[a-zA-Z0-9]+') AS username
FROM ARTICLE
WHERE "A" !~ '^[a-zA-Z0-9]+\s\(.*\)$';

DELETE FROM ARTICLE
WHERE "A" = '子瑜是妳？                               49.218.48.184';

UPDATE ARTICLE SET "F" = "E", "E" = '115.43.72.67'
WHERE ("A" = '貓貓 (k1tten)' AND "C" = '[問卦] 貓咪半夜是不是都不睡覺？');

-- update username accordingly
UPDATE ARTICLE SET "A" = (
	CASE "A"
	WHEN '貓貓 (k1tten)' THEN 'realever32'
	WHEN '梁文傑' THEN 'NULLUSER01'
	WHEN '好吃好吃 (真心不騙)' THEN 'judiciary'
	ELSE substring("A" FROM '^[a-zA-Z0-9]+') END);

-- rename the column
ALTER TABLE ARTICLE RENAME "A" TO Username;

--- deleting bad entries that are not from Gossiping or reposts
SELECT * FROM ARTICLE WHERE "B" != 'Gossiping';

DELETE FROM ARTICLE
WHERE "B" = 'HatePolitics' OR "B" = 'Car' OR "B" = 'sex';

ALTER TABLE ARTICLE DROP COLUMN "B";

--- Separate article info from the title
-- check for the bad lines
SELECT * FROM ARTICLE
WHERE "C" !~ '^(Re:\s*|Fw:\s*|R:\s*|re:\s*)*(\[|\{|［)(.*)(\]|］|\})\s*(.*)$';

-- create new variables to fill
ALTER TABLE ARTICLE
ADD COLUMN re_status INT,
ADD COLUMN fw_status INT,
ADD COLUMN arti_class varchar(10),
ADD COLUMN arti_title text;

-- deal with the good lines, separate re/fw type, artical class, and title
WITH p(pattern) AS (
  SELECT '(?i)^(Re:\s*|R:\s*)*(Fw:\s*)*(\[|\{|［|【)(.*?)(\]|］|\}|】)\s*(.*)$'
)
UPDATE ARTICLE
SET (re_status, fw_status, arti_class, arti_title) = (
	SELECT 
	(CASE WHEN m[1] IS NULL THEN 0 ELSE 1 END), 
	(CASE WHEN m[2] IS NULL THEN 0 ELSE 1 END), 
	m[4], m[6]
	FROM regexp_matches("C", pattern) m)
FROM p
WHERE  "C" ~ '(?i)^(Re:\s*|Fw:\s*|R:\s*|Re:)*(\[|\{|［|【)(.*)(\]|］|\}|】)\s*(.*)$';

UPDATE ARTICLE SET arti_class = (
	CASE arti_class
	WHEN '問卦 貓貓的腳腳' THEN '問卦'
	WHEN 'live' THEN 'Live'
	WHEN 'FB' THEN 'ＦＢ'
	WHEN 'F  B' THEN 'ＦＢ'
	WHEN '協尋記錄器' THEN '協尋'
	WHEN '築地搬遷' THEN '新聞'
	ELSE arti_class END);

-- deal with the bad lines - special cases first
WITH p2(pattern) AS (
  SELECT '^\[(問卦|問|新聞)\s*(.*)$'
)
UPDATE ARTICLE
SET (re_status, fw_status, arti_class, arti_title) = (SELECT 0, 0, m[1], m[2] FROM regexp_matches("C", pattern) m)
FROM p2
WHERE  arti_class is NULL;

WITH p3(pattern) AS (
  SELECT '^(Re:\s*).*?(\[|\(|「)(.*)(\]|\)|」)\s*(.*)$'
)
UPDATE ARTICLE
SET (re_status, fw_status, arti_class, arti_title) = (SELECT 1, 0, m[3], m[5] FROM regexp_matches("C", pattern) m)
FROM p3
WHERE  arti_class is NULL;

WITH p4(pattern) AS (
  SELECT '^(Re:\s*)*(協尋)\s*(.*)$'
)
UPDATE ARTICLE
SET (re_status, fw_status, arti_class, arti_title) = (
	SELECT 
	(CASE WHEN m[1] IS NULL THEN 0 ELSE 1 END),0, m[2], m[3] 
	FROM regexp_matches("C", pattern) m)
FROM p4
WHERE  arti_class is NULL;

UPDATE ARTICLE
SET (re_status, fw_status, arti_class, arti_title) = (1,0,'發錢','抓到國民黨最新創作白米篇')
WHERE  "C" = '(發錢) Re: [爆卦] 抓到國民黨最新創作白米篇';

UPDATE ARTICLE
SET (re_status, fw_status, arti_class, arti_title) = (0,0,'爆卦','乃木坂46臺北演唱會============發錢====================')
WHERE  "C" = '□ [爆卦] 乃木坂46臺北演唱會============發錢====================';

UPDATE ARTICLE
SET (re_status, fw_status, arti_class, arti_title) = (0,0,'新聞','查韓國瑜帳查到變支持者！會計師：這')
WHERE  "C" = '轉 [新聞] 查韓國瑜帳查到變支持者！會計師：這';

WITH p5(pattern) AS (
  SELECT '(?i)^(Re:\s*)*(Fw:\s*)*(.*)$'
)
UPDATE ARTICLE
SET (re_status, fw_status, arti_class, arti_title) = (
	SELECT 
	(CASE WHEN m[1] IS NULL THEN 0 ELSE 1 END),
	(CASE WHEN m[2] IS NULL THEN 0 ELSE 1 END), 
	'Empty', m[3] FROM regexp_matches("C", pattern) m)
FROM p5
WHERE  arti_class is NULL;

-- rename the column, keep C for merging purpose
ALTER TABLE ARTICLE RENAME "C" TO Orig_title;

--- reformat the timestamps
-- generate new variable 
ALTER TABLE ARTICLE
ADD COLUMN post_date timestamp;
-- detect the bad lines first
SELECT * FROM article WHERE "D" !~ '[A-Z]{1}[a-z]{2}\s[A-Z]{1}[a-z]{2}\s+\d{1,2}\s\d{2}:\d{2}:\d{2}\s\d{4}';

-- update the date altogether
UPDATE ARTICLE
SET post_date = (
	CASE "D"
	WHEN '8/17' THEN TO_TIMESTAMP('2018/08/17 07:31:00', 'YYYY/MM/DD HH24:MI:SS')
	WHEN 'Fri Aug 24' THEN TO_TIMESTAMP('2018/08/24 12:00:00', 'YYYY/MM/DD HH24:MI:SS')
	WHEN 'Sun Sep  9 13:59:33 201' THEN TO_TIMESTAMP('Sun Sep  9 13:59:33 2018', 'Dy Mon DD HH24:MI:SS YYYY')
	WHEN 'Sat Sep 15 19:31:13 201' THEN TO_TIMESTAMP('Sat Sep 15 19:31:13 2018', 'Dy Mon DD HH24:MI:SS YYYY')
	WHEN 'Sat Oct 13 10:27:54' THEN TO_TIMESTAMP('Sat Oct 13 10:27:54 2018', 'Dy Mon DD HH24:MI:SS YYYY')
	WHEN 'pitbull0123 (鬥牛犬汪汪) 看板: Gossiping' 
	THEN TO_TIMESTAMP('Thu Oct 25 14:36:58 2018', 'Dy Mon DD HH24:MI:SS YYYY')
	WHEN 'Sat Nov 24 11:21:29' THEN TO_TIMESTAMP('Sat Nov 24 11:21:29 2018', 'Dy Mon DD HH24:MI:SS YYYY')
	WHEN 'Sat Nov 24 20:51:23 20' THEN TO_TIMESTAMP('Sat Nov 24 20:51:23 2018', 'Dy Mon DD HH24:MI:SS YYYY')
	WHEN 'Tue Nov 27 11:23:07' THEN TO_TIMESTAMP('Tue Nov 27 11:23:07 2018', 'Dy Mon DD HH24:MI:SS YYYY')
	ELSE TO_TIMESTAMP("D", 'Dy Mon DD HH24:MI:SS YYYY') END);

ALTER TABLE ARTICLE DROP COLUMN "D";

--- now capture the content as well as the ip address
-- ideally, each observation should contain only one IP address. However, there could be more for a single
-- observation in this data set if it contains the content of multiple posts (a stream of posts)
-- in that case, the last legit IP adress is the address should be attributed to the post, and I am going 
-- to keep only this IP adress and drop the others

ALTER TABLE ARTICLE ADD COLUMN post_IP varchar(20);

WITH IP(pattern) AS (
  SELECT '^(((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?){4})$'
)
UPDATE ARTICLE
SET post_IP = COALESCE(
	(SELECT y[1] FROM regexp_matches("Y", pattern) as y),(SELECT x[1] FROM regexp_matches("X", pattern) as x),
	(SELECT w[1] FROM regexp_matches("W", pattern) as w),(SELECT v[1] FROM regexp_matches("V", pattern) as v),
	(SELECT u[1] FROM regexp_matches("U", pattern) as u),(SELECT t[1] FROM regexp_matches("T", pattern) as t),
	(SELECT s[1] FROM regexp_matches("S", pattern) as s),(SELECT r[1] FROM regexp_matches("R", pattern) as r),
	(SELECT q[1] FROM regexp_matches("Q", pattern) as q),(SELECT p[1] FROM regexp_matches("P", pattern) as p),
	(SELECT o[1] FROM regexp_matches("O", pattern) as o),(SELECT n[1] FROM regexp_matches("N", pattern) as n),
	(SELECT m[1] FROM regexp_matches("M", pattern) as m),(SELECT l[1] FROM regexp_matches("L", pattern) as l),
	(SELECT k[1] FROM regexp_matches("K", pattern) as k),(SELECT j[1] FROM regexp_matches("J", pattern) as j),
	(SELECT i[1] FROM regexp_matches("I", pattern) as i),(SELECT h[1] FROM regexp_matches("H", pattern) as h),
	(SELECT G[1] FROM regexp_matches("G", pattern) as g),(SELECT F[1] FROM regexp_matches("F", pattern) as f),
	(SELECT E[1] FROM regexp_matches("E", pattern) as e),'EMPTY')
FROM IP;

ALTER TABLE ARTICLE ADD COLUMN post_content text;

UPDATE ARTICLE
SET post_content = COALESCE(
	NULLIF("Z",''),NULLIF("Y",''),NULLIF("X",''),NULLIF("W",''),NULLIF("V",''),
	NULLIF("U",''),NULLIF("T",''),NULLIF("S",''),NULLIF("R",''),NULLIF("Q",''),
	NULLIF("P",''),NULLIF("O",''),NULLIF("N",''),NULLIF("M",''),NULLIF("L",''),
	NULLIF("K",''),NULLIF("J",''),NULLIF("I",''),NULLIF("H",''),NULLIF("G",''),
	NULLIF("F",''),'EMPTY');

UPDATE ARTICLE
SET post_content = COALESCE(NULLIF("F",''),NULLIF("E",''),'EMPTY')
WHERE post_ip = 'EMPTY';

-- change ip to the right data fromat 
ALTER TABLE ARTICLE ADD COLUMN ip_new inet;

UPDATE ARTICLE 
SET ip_new = (CASE WHEN post_ip = 'EMPTY' THEN NULL ELSE post_ip::inet END);

ALTER TABLE ARTICLE DROP COLUMN post_ip;

ALTER TABLE ARTICLE RENAME COLUMN ip_new TO post_ip;

-- deleting redundent columns

ALTER TABLE ARTICLE 
DROP COLUMN "Z", DROP COLUMN "Y", DROP COLUMN "X", DROP COLUMN "W", DROP COLUMN "V", DROP COLUMN "U", 
DROP COLUMN "T", DROP COLUMN "S", DROP COLUMN "R", DROP COLUMN "Q", DROP COLUMN "P", DROP COLUMN "O",
DROP COLUMN "N", DROP COLUMN "M", DROP COLUMN "L", DROP COLUMN "K", DROP COLUMN "J", DROP COLUMN "I",
DROP COLUMN "H", DROP COLUMN "G", DROP COLUMN "F", DROP COLUMN "E";

SELECT * FROM ARTICLE
