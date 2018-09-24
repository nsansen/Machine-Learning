-- 1. Βρες το άθροισμα των εργαστηριακών ωρών 
-- για τα μαθήματα του πρώτου εξαμήνου σπουδών
-- καθώς και το πλήθος των μαθημάτων αυτών
SELECT SUM(lecture_hours),COUNT(*)
FROM "Course"
WHERE typical_year=1 and typical_season='winter'

-- 2. Εμφάνισε το πλήθος των διδακτικών μονάδων 
-- των υποχρεωτικών μαθημάτων σε κάθε έτος σπουδών
-- και ταξινόμησε με βάση το πλήθος σε αύξουσα (φθίνουσα) σειρά
SELECT typical_year, SUM(units) as units
FROM "Course"
WHERE obligatory
GROUP BY typical_year
ORDER BY units -- DESC

-- 3. Βρες τον κωδικό και την περιγραφή των μαθημάτων 
-- που έχουν τις ελάχιστες διδακτικές μονάδες
SELECT d.course_description,d.course_code
FROM "Course_description" d, 
	(SELECT course_code
	 FROM "Course"
	 WHERE units <= ALL (SELECT units
						 FROM "Course") 
	) c
WHERE d.course_code = c.course_code
-- Εναλλακτικά
SELECT d.course_description,d.course_code
FROM "Course_description" d, 
	(SELECT course_code
	 FROM "Course"
	 WHERE units = (SELECT MIN(units)
						 FROM "Course") 
	) c
WHERE d.course_code = c.course_code

-- 4. Βρες το μέγιστο συνολικό πλήθος διδακτικών μονάδων 
-- υποχρεωτικών μαθημάτων στα εξάμηνα σπουδών
SELECT MAX(total_units) 
FROM (	SELECT SUM(units) as total_units
	FROM "Course"
	WHERE obligatory
	GROUP BY typical_year, typical_season) s

-- 5. Βρες το εξάμηνο σπουδών με το μέγιστο συνολικό πλήθος 
-- διδακτικών μονάδων υποχρεωτικών μαθημάτων
SELECT typical_year, typical_season --, SUM(units)
FROM "Course"
WHERE obligatory
GROUP BY typical_year, typical_season
HAVING SUM(units) = (
	SELECT MAX(total_units) 
	FROM (	SELECT SUM(units) as total_units
		FROM "Course"
		WHERE obligatory
		GROUP BY typical_year, typical_season) s)
-- Εναλλακτική που δεν θα λειτουργήσει αν υπάρχουν παραπάνω
-- από ένα εξάμηνα που ικανοποιούν τη συνθήκη
SELECT typical_year, typical_season,SUM(units) as total_units
FROM "Course"
WHERE obligatory
GROUP BY typical_year, typical_season
ORDER BY total_units DESC
LIMIT 1

-- 6. Βρες τους κωδικούς των μαθημάτων 
-- που δεν έχουν προαπαιτούμενα ή συνιστώμενα μαθήματα
SELECT c.course_code
FROM "Course" c LEFT OUTER JOIN "Course_depends" d ON c.course_code = d.dependent
WHERE d.mode IS NULL
-- Εναλλακτική
SELECT course_code FROM "Course"
EXCEPT
SELECT dependent FROM "Course_depends"

-- 7. Βρες το πλήθος των υποχρεωτικών μαθημάτων κάθε εξαμήνου 
-- εμφανίζοντας όλα τα εξάμηνα στο αποτέλεσμα
SELECT DISTINCT c.typical_year, c.typical_season, 
	   CASE 
	   		WHEN cnt IS NULL THEN 0 
			ELSE cnt
	   END
FROM "Course" c LEFT OUTER JOIN (
		SELECT typical_year, typical_season, COUNT(*) as cnt
		FROM "Course"
		WHERE obligatory
		GROUP BY typical_year, typical_season 
	) cc USING (typical_year,typical_season)

-- 8. Βρες ζεύγη κωδικών για μαθήματα που εξαρτώνται άμεσα ή έμμεσα 
-- το ένα από το άλλο μέσω προαπαιτουμένων μαθημάτων υπολογίζοντας και
-- το μήκος της ακολουθίας των άμεσων προαπαιτούμενων για κάθε ζεύγος.
WITH RECURSIVE Req(anc,des,length) AS (
	SELECT main as anc,dependent as des, 1 as length FROM "Course_depends" WHERE mode='required'
	UNION
	SELECT r.anc as anc,d.dependent as des, r.length+1 as length
	FROM Req r, "Course_depends" d
	WHERE r.des = d.main AND mode='required'
)
SELECT * FROM Req

-- Τι θα συμβεί αν δημιουργήσουμε έναν κύκλο στο γράφημα;
INSERT INTO "Course_depends"(main,dependent,mode)
VALUES ('ΠΛΗ 301','ΠΛΗ 101','required')

DELETE FROM "Course_depends"
WHERE main='ΠΛΗ 301' AND dependent='ΠΛΗ 101'

-- 9. Βρες ζεύγη κωδικών για μαθήματα που εξαρτώνται άμεσα ή έμμεσα 
-- το ένα από το άλλο μέσω προαπαιτουμένων μαθημάτων εμφανίζοντας και
-- την ακολουθία (μονοπάτι) των άμεσων προαπαιτούμενων για κάθε ζεύγος.
WITH RECURSIVE Req(anc,des,path) AS (
	SELECT main as anc,dependent as des, CONCAT(main,',',dependent) as path 
	FROM "Course_depends" WHERE mode='required'
	UNION
	SELECT r.anc as anc,d.dependent as des, CONCAT(r.path,',',d.dependent) as path
	FROM Req r, "Course_depends" d
	WHERE r.des = d.main AND mode='required'
)
SELECT * FROM Req

-- Relational Division - ΣχεσιακήΔιαίρεση
-- 10. Βρες τους φοιτητές που έχουν περάσει όλα τα υποχρεωτικά μαθήματα

-- Η παρακάτω μορφή, αν δεν υπάρχει κανένα υποχρεωτικό μάθημα, δεν θα επιστρέψει
-- κανένα φοιτητή (αντικαταστήστε το c.obligatory με false)
SELECT amka
FROM "Register" r NATURAL JOIN "Course" c
WHERE c.obligatory AND r.register_status='pass'
GROUP BY amka
HAVING COUNT(*)= (SELECT count(*) FROM "Course" WHERE obligatory)

-- Η παρακάτω μορφή αν δεν υπάρχει κανένα υποχρεωτικό μάθημα θα επιστρέψει
-- το σύνολο των φοιτητών (αντικαταστήστε το obligatory με false)
-- Μοιάζει με την υλοποίηση της ερώτησης 8 στο queryExamples1.sql
SELECT DISTINCT amka
FROM "Register" AS x
WHERE register_status='pass' AND NOT EXISTS (
	SELECT course_code 
	FROM "Course" as y
	WHERE obligatory
	EXCEPT 
	SELECT course_code
	FROM "Register" as z
	WHERE register_status='pass' AND z.amka=x.amka 
)

-- Ισοδύναμη (με ελαφρά διαφορετική σημασιολογία) έκφραση της προηγούμενης μορφής 
-- της ερώτησης η οποία έχει πολύ καλύτερο χρόνο υπολογισμού
SELECT DISTINCT amka
FROM "Register" AS x
WHERE register_status='pass' AND NOT EXISTS (
	SELECT course_code 
	FROM "Course" as y
	WHERE obligatory AND NOT EXISTS (
		SELECT amka, course_code
		FROM "Register" as z
		WHERE register_status='pass' AND z.amka=x.amka AND z.course_code=y.course_code 
	) 
)

-- Χρήση μετονομασίας για απλοποίηση της μορφής των ερωτήσεων
WITH R(a,b) AS (
	SELECT amka,course_code
	FROM "Register"
	WHERE register_status='pass'
), S(b) AS (
	SELECT course_code
	FROM "Course"
	WHERE obligatory
)

-- Υπολογισμός με άμεση εφαρμογή του ορισμού της πράξης της σχεσιακής διαίρεσης
-- R(a,b) / S*b) = π a (R) - π a ( (π a (R) X S) - R )
-- Χρησιμοποιείστε την ανωτέρω μετονομασία για την εκτέλεση της ερώτησης
SELECT a FROM R
EXCEPT
SELECT a FROM (
	SELECT a,b FROM (SELECT a from R) x, (SELECT b from S) y
	EXCEPT
	SELECT a,b FROM R
) z

-- Απλοποίηση υπολογισμού με χρήση της λογικής ισοδυναμίας:
-- foreach a (there is b such that f(a,b) <=> there is no a (there is no b such that not f(a,b)
-- "Find a's such that there is no b in the set (all b's) - (b's matched with specific a)
-- Χρησιμοποιείστε την ανωτέρω μετονομασία για την εκτέλεση της ερώτησης
SELECT DISTINCT a FROM R AS x1 WHERE NOT EXISTS (
	SELECT b FROM S 
	EXCEPT
	SELECT b FROM R AS x2 WHERE x1.a=x2.a
)

-- Διαφοροποιημένη εκδοχή για ταχύτερο χρόνο εκτέλεσης
-- Χρησιμοποιείστε την ανωτέρω μετονομασία για την εκτέλεση της ερώτησης
SELECT DISTINCT a FROM R AS x WHERE NOT EXISTS (
	SELECT b FROM S AS y WHERE NOT EXISTS (
		SELECT * FROM R AS z WHERE x.a=z.a and y.b=z.b
	)
)




