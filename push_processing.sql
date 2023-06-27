----- The dataset used here is upon request
----- extracting information for each article to merge with article table
CREATE TABLE public.PUSH
(
    "A" varchar(100),"B" varchar(100),"C" varchar(100),"D" varchar(10),
	"E" varchar(100),"F" varchar(100),"G" varchar(1000)
);
-- data should be imported with delimiter = ;, leave Quote, Escape, 
-- Null string empty, header = Null

--- Re-formatting username
-- find out the ill-formatted usernames 
SELECT DISTINCT "A", "C" FROM PUSH WHERE "A" !~ '^[a-zA-Z0-9]+\s\(.*\)$';

SELECT DISTINCT "A", substring("A" FROM '^[a-zA-Z0-9]+') AS username
FROM PUSH
WHERE "A" !~ '^[a-zA-Z0-9]+\s\(.*\)$';
-- they're the same across two datasets -> process them with the same procedure 

DELETE FROM PUSH
WHERE "A" = '子瑜是妳？                               49.218.48.184';

UPDATE PUSH SET "A" = (
	CASE "A"
	WHEN '貓貓 (k1tten)' THEN 'realever32'
	WHEN '梁文傑' THEN 'NULLUSER01'
	WHEN '好吃好吃 (真心不騙)' THEN 'judiciary'
	ELSE substring("A" FROM '^[a-zA-Z0-9]+') END);
	
-- rename the column
ALTER TABLE PUSH RENAME "A" TO Username;

--- deleting articles from the wrong channel
SELECT * FROM PUSH WHERE "B" != 'Gossiping';

DELETE FROM PUSH
WHERE "B" = 'HatePolitics' OR "B" = 'Car' OR "B" = 'sex';

ALTER TABLE PUSH DROP COLUMN "B";

--- rename column C,D
ALTER TABLE PUSH RENAME "C" TO orig_title;
ALTER TABLE PUSH RENAME "D" TO push_status;
ALTER TABLE PUSH RENAME "E" TO push_user;
ALTER TABLE PUSH RENAME "F" TO push_content;

--- deal with bad usernames
SELECT * FROM PUSH WHERE push_user !~ '^[A-Za-z0-9]+$';
-- bad usename lines comes in one of the following form 1. ^[A-Za-z0-9]+(;41)[A-Za-z0-9]+$ 
-- 2.^[A-Za-z0-9]+:$ 3. others with multiple '*', the first two cases are ligit, the last one 
-- should be excluded
UPDATE PUSH SET push_user = (
	CASE 
	WHEN push_user ~ '^[A-Za-z0-9]+(;41)+[A-Za-z0-9]+$' THEN REGEXP_REPLACE(push_user, '(;41)+', '', 'g')
	WHEN push_user ~ '^[A-Za-z0-9]+:$' THEN REPLACE(push_user, ':', '')
	ELSE push_user END);
	
DELETE FROM PUSH WHERE push_user !~ '^[A-Za-z0-9]+$';

--- Removing : from F and rename F
SELECT * FROM PUSH WHERE push_content !~ '^:.*$';
-- keep only the entry attatched with a post from Holmes7
DELETE FROM PUSH WHERE (push_content !~ '^:.*$') AND (username != 'Holmes7');
-- removing : and potential spaces
UPDATE PUSH SET push_content = (
	CASE 
	WHEN push_content ~ '^:.*$' THEN REGEXP_REPLACE(push_content, ':\s*', '', 'g')
	ELSE push_content END);

--- separate date and ip from G
-- detecting bad lines
SELECT * FROM PUSH WHERE "G" !~ '^(((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?){4})*\s*((0[1-9]|1[0-2])\/(0[1-9]|[1-2][0-9]|3[0-1])\s*([0-1][0-9]|2[0-3]):([0-5][0-9]))';
-- these are edited lines that could not be recovered, removed from the analysis
DELETE FROM PUSH WHERE "G" !~ '^(((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?){4})*\s*((0[1-9]|1[0-2])\/(0[1-9]|[1-2][0-9]|3[0-1])\s*([0-1][0-9]|2[0-3]):([0-5][0-9]))';
-- create new variables to store timestamp and ip address
ALTER TABLE PUSH
ADD COLUMN IP_address varchar(20),
ADD COLUMN push_date timestamp;

-- deleting signature
DELETE FROM PUSH WHERE push_content = '哪有沒好貨  大小威廉斯我最愛';

WITH p(pattern) AS (
  SELECT '^(((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?){4})*\s*((0[1-9]|1[0-2])\/(0[1-9]|[1-2][0-9]|3[0-1])\s*([0-1][0-9]|2[0-3]):([0-5][0-9]))'
)
UPDATE PUSH
SET (IP_address, push_date) = (SELECT 
	(CASE WHEN m[1] IS NULL THEN 'NO_IP' ELSE m[1] END), 
	(CASE 
	WHEN m[5] IS NULL THEN NULL 
	WHEN m[1] IS NULL AND m[6] ~ '^0[1-5]$' THEN TO_TIMESTAMP('2019/' || m[5] , 'YYYY/MM/DD HH24:MI')
	WHEN m[6] = '06' THEN TO_TIMESTAMP('2019/' || m[5] , 'YYYY/MM/DD HH24:MI')
	WHEN m[1] IS NULL AND m[6] ~ '^1[12]$' THEN TO_TIMESTAMP('2018/' || m[5] , 'YYYY/MM/DD HH24:MI')
	WHEN m[1] IS NOT NULL AND ((m[6] = '12') OR (m[6] = '11' AND m[7] ~'(2[6-9]|30)')) THEN TO_TIMESTAMP('2019/' || m[5] , 'YYYY/MM/DD HH24:MI')
	WHEN m[1] IS NOT NULL AND m[6] ~ '^(01|02|03)$' THEN TO_TIMESTAMP('2020/' || m[5] , 'YYYY/MM/DD HH24:MI')
	WHEN m[1] IS NULL AND m[6] ~ '^(0[7-9]|10)$' THEN TO_TIMESTAMP('2015/' || m[5] , 'YYYY/MM/DD HH24:MI') -- set for later deletion
	ELSE TO_TIMESTAMP('2018/' || m[5] , 'YYYY/MM/DD HH24:MI') END)
	FROM regexp_matches("G", pattern) m)
FROM p;

-- deleting weird pushes: showing july, august, september october but no IP address -> either being edited
-- or they are personal signatures
DELETE FROM PUSH WHERE push_date < '2018-01-01';
DELETE FROM PUSH WHERE IP_address = 'NO_IP' AND push_date BETWEEN '2018-11-01' AND '2018-11-25 15:00';

--- detecting and deleting signatures
SELECT username, push_status, push_user, push_content, "G", ip_address, count(*), count(DISTINCT orig_title)
FROM PUSH 
GROUP BY username, push_status, push_user, push_content, "G", ip_address
HAVING count(*) > 1 AND count(DISTINCT orig_title) >1
ORDER BY count(*) DESC;

SELECT push_status, push_user, push_content, "G", ip_address, count(*) 
FROM PUSH
WHERE push_date NOT BETWEEN '2018-11-17' AND '2018-12-01'
GROUP BY push_status, push_user, push_content, "G", ip_address
HAVING count(*) > 1
ORDER BY count(*) DESC;

-- deleting pushes following certain criteria
-- duplicated pushes that appears on multiple different articles with the same content, timestamp, 
-- IP address from the same user will be identified as signatures

-- though some of the articles might be affected if an user copied everything from her perious post
-- and pasted them to a new post including all the pushed, the impact should be minor as this does
-- not happen as often. At max 10 posts will get imprecise pushes results, others should be fine.

-- regular delete join command were not supported in postgresql
/* 
DELETE A FROM PUSH A
INNER JOIN (
	SELECT username, push_status, push_user, push_content, "G", ip_address, count(*), count(DISTINCT orig_title)
	FROM PUSH 
	GROUP BY username, push_status, push_user, push_content, "G", ip_address
	HAVING count(*) > 1 AND count(DISTINCT orig_title) >1) S
ON  A.push_status = S.push_status
AND A.push_user = S.push_user
AND A.push_content = S.push_content
AND A."G" = S."G";
*/

DELETE FROM PUSH A
USING (
	SELECT username, push_status, push_user, push_content, "G", count(*), count(DISTINCT orig_title)
	FROM PUSH 
	GROUP BY username, push_status, push_user, push_content, "G"
	HAVING count(*) > 1 AND count(DISTINCT orig_title) >1
	) S
WHERE A.push_status = S.push_status
AND A.push_user = S.push_user
AND A.push_content = S.push_content
AND A."G" = S."G";

-- the push data is ready to use
