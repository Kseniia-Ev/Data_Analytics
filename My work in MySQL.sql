/* SQL Step Project
2026-07-07
by KE*/

-- Queries

-- 1. Покажіть середню зарплату співробітників за кожен рік, до 2005 року.
USE employees;

SELECT 
      YEAR(sal.from_date) AS years,
      ROUND(AVG(sal.salary), 2) AS average_salary
FROM employees.employees emp
INNER JOIN employees.salaries sal
         ON emp.emp_no = sal.emp_no
WHERE sal.from_date < '2005-01-01'
GROUP BY YEAR(sal.from_date)
ORDER BY years;

/* 2. Покажіть середню зарплату співробітників по кожному відділу.
 Примітка: потрібно розрахувати по поточній зарплаті, та поточному відділу співробітників*/
SELECT 
		dep.dept_name AS department_names,
        ROUND(AVG(sal.salary), 2) AS average_salary
FROM  employees.departments dep
INNER JOIN employees.dept_emp demp
        ON dep.dept_no = demp.dept_no
		AND demp.to_date > CURDATE()
INNER JOIN employees.salaries sal
        ON demp.emp_no = sal.emp_no
        AND sal.to_date > CURDATE()
 GROUP BY demp.dept_no,
		  dep.dept_name
 ORDER BY average_salary DESC;
  
 
CREATE OR REPLACE VIEW  employees.v_dep_avg_sal
AS
  SELECT 
		dep.dept_name AS department_names,
        ROUND(AVG(sal.salary), 2) AS average_salary
FROM  employees.departments dep
INNER JOIN employees.dept_emp demp
        ON dep.dept_no = demp.dept_no
		AND demp.to_date > CURDATE()
INNER JOIN employees.salaries sal
        ON demp.emp_no = sal.emp_no
        AND sal.to_date > CURDATE()
 GROUP BY demp.dept_no,
		  dep.dept_name
 ORDER BY average_salary DESC;
 
 SELECT *
 FROM employees.v_dep_avg_sal;
 
-- 3. Покажіть середню зарплату співробітників по кожному відділу за кожний рік
SELECT
	  dep.dept_name AS department_names,
      YEAR(sal.from_date) AS years,
      ROUND(AVG(sal.salary), 2) AS average_salary
FROM  employees.departments dep
INNER JOIN employees.dept_emp demp
        ON dep.dept_no = demp.dept_no
INNER JOIN employees.salaries sal
        ON demp.emp_no = sal.emp_no
        AND (sal.from_date BETWEEN demp.from_date AND demp.to_date
		OR sal.to_date BETWEEN demp.from_date AND demp.to_date)       
GROUP BY dep.dept_name,
         YEAR(sal.from_date)
ORDER BY department_names,
         average_salary;
       
-- 4. Покажіть відділи в яких зараз працює більше 15000 співробітників.
-- 1 var CTE
WITH cte_count_dept
AS
(
	SELECT dept_no
	FROM  employees.dept_emp
	WHERE to_date > CURDATE()
	GROUP BY dept_no
	HAVING COUNT(emp_no) > 15000
)
SELECT ccd.dept_no,
       dep.dept_name AS department_name
FROM employees.departments dep
INNER JOIN cte_count_dept ccd
      ON dep.dept_no = ccd.dept_no
ORDER BY ccd.dept_no,
       dep.dept_name;
       
-- 2 var temporary table
CREATE TEMPORARY TABLE IF NOT EXISTS count_depts
AS
    SELECT dept_no,
           COUNT(emp_no) AS emp_count
	FROM  employees.dept_emp
	WHERE to_date > CURDATE()
	GROUP BY dept_no;
    
SELECT *
FROM count_depts;

SELECT cd.dept_no,
       dep.dept_name AS department_name
FROM employees.departments dep
INNER JOIN count_depts cd
      ON dep.dept_no = cd.dept_no
WHERE cd.emp_count > 15000
ORDER BY cd.dept_no,
         dep.dept_name;

DROP TEMPORARY TABLE IF EXISTS count_depts;

-- 3 var 
SELECT 
       demp.dept_no,
       dep.dept_name,
       COUNT(emp_no) AS emp_count
FROM employees.dept_emp demp
INNER JOIN employees.departments dep
       ON demp.dept_no = dep.dept_no
WHERE demp.to_date > CURDATE()
GROUP BY demp.dept_no,
         dep.dept_name
HAVING COUNT(emp_no) > 15000
ORDER BY emp_count DESC;

-- 5. Для менеджера який працює найдовше покажіть його номер, відділ, дату прийому на роботу, прізвище
SELECT 
      emp.emp_no,
      dep.dept_name,
      emp.hire_date,
      emp.last_name
FROM employees.employees emp
INNER JOIN employees.dept_emp demp
       ON emp.emp_no = demp.emp_no
INNER JOIN employees.departments dep
       ON demp.dept_no = dep.dept_no
INNER JOIN employees.dept_manager dmng
       ON emp.emp_no = dmng.emp_no
       AND dmng.to_date > CURDATE()
ORDER BY emp.hire_date
LIMIT 1;

-- 2 var CTE
WITH long_serv_mng AS(
	SELECT MIN(emp.hire_date) AS min_hire_date
    FROM employees.employees emp
    INNER JOIN employees.dept_manager dmng
		ON emp.emp_no = dmng.emp_no
        AND dmng.to_date > CURDATE()
)
SELECT 
      emp.emp_no,
      dep.dept_name,
      emp.hire_date,
      emp.last_name
FROM employees.employees emp
INNER JOIN employees.dept_emp demp
       ON emp.emp_no = demp.emp_no
INNER JOIN employees.departments dep
       ON demp.dept_no = dep.dept_no
INNER JOIN employees.dept_manager dmng
	ON emp.emp_no = dmng.emp_no
	AND dmng.to_date > CURDATE()
INNER JOIN long_serv_mng lsm
	ON emp.hire_date = lsm.min_hire_date;

/* 6. Покажіть топ-10 діючих співробітників компанії з найбільшою різницею між їх зарплатою 
і середньою зарплатою в їх відділі.*/
-- 1 var CTE
WITH cte_sal_demp
AS
(
	SELECT
		   sal.emp_no,
		   demp.dept_no,
		   sal.salary
	FROM employees.salaries sal
	INNER JOIN employees.dept_emp demp
		  ON sal.emp_no = demp.emp_no
	WHERE sal.to_date > CURDATE()
	  AND demp.to_date > CURDATE()
),
cte_avg_demp
AS
(
	SELECT
          dept_no,
          ROUND(AVG(salary), 2) AS avg_dept_sal
    FROM cte_sal_demp
    GROUP BY dept_no
)
SELECT 
      csd.emp_no,
      CONCAT(last_name, " ", first_name) AS full_name,
      dep.dept_name,
      csd.salary,
      cad.avg_dept_sal,
      csd.salary - cad.avg_dept_sal AS diff_salary
FROM cte_sal_demp csd
INNER JOIN cte_avg_demp cad
     ON csd.dept_no = cad.dept_no
INNER JOIN employees.departments dep
     ON cad.dept_no = dep.dept_no
INNER JOIN employees.employees emp
     ON csd.emp_no = emp.emp_no
ORDER BY diff_salary DESC
LIMIT 10;

-- 2 var 
CREATE TEMPORARY TABLE IF NOT EXISTS sal_demp
AS
SELECT
	   sal.emp_no,
	   demp.dept_no,
	   sal.salary
FROM employees.salaries sal
INNER JOIN employees.dept_emp demp
	    ON sal.emp_no = demp.emp_no
WHERE sal.to_date > CURDATE()
  AND demp.to_date > CURDATE();
  
SELECT *
FROM sal_demp;

CREATE TEMPORARY TABLE IF NOT EXISTS avg_demp
SELECT
       dept_no,
       ROUND(AVG(salary), 2) AS avg_dept_sal
FROM sal_demp
GROUP BY dept_no;

SELECT *
FROM avg_demp;

SELECT 
      sd.emp_no,
      CONCAT(last_name, " ", first_name) AS full_name,
      dep.dept_name,
      sd.salary,
      ad.avg_dept_sal,
      sd.salary - ad.avg_dept_sal AS diff_salary
FROM sal_demp sd
INNER JOIN avg_demp ad
     ON sd.dept_no = ad.dept_no
INNER JOIN employees.departments dep
     ON ad.dept_no = dep.dept_no
INNER JOIN employees.employees emp
     ON sd.emp_no = emp.emp_no
ORDER BY diff_salary DESC
LIMIT 10;

DROP TEMPORARY TABLE IF EXISTS sal_demp;
DROP TEMPORARY TABLE IF EXISTS avg_demp;


/* 7. Для кожного відділу покажіть другого по порядку менеджера. Необхідно вивести відділ,
 прізвище ім’я менеджера, дату прийому на роботу менеджера і дату коли він став менеджером відділу*/
WITH row_n_dm
AS
( 
	SELECT
          dep.dept_name AS department,
          CONCAT(last_name, " ", first_name) AS manager_name,
          emp.hire_date AS emp_hire_date,
          dm.from_date AS manager_from_date,
          ROW_NUMBER() OVER (PARTITION BY dm.dept_no ORDER BY dm.dept_no, dm.from_date) AS row_n
	FROM employees.dept_manager dm
    INNER JOIN employees.departments dep
            ON dm.dept_no = dep.dept_no
	INNER JOIN employees.employees emp
            ON dm.emp_no =emp.emp_no
) 
 SELECT 
       department,
       manager_name,
       emp_hire_date,
       manager_from_date
 FROM row_n_dm
 WHERE row_n = 2;
 
/* Дизайн бази даних:
 1. Створіть базу даних для управління курсами. База має включати наступні таблиці:
- students: student_no, teacher_no, course_no, student_name, email, birth_date.
- teachers: teacher_no, teacher_name, phone_no
- courses: course_no, course_name, start_date, end_date

2. Додайте будь-які данні (7-10 рядків) в кожну таблицю.
3. По кожному викладачу покажіть кількість студентів з якими він працював
4. Спеціально зробіть 3 дубляжі в таблиці students (додайте ще 3 однакові рядки) 
5. Напишіть запит який виведе дублюючі рядки в таблиці students */
 
CREATE DATABASE IF NOT EXISTS Course_Mg;

SHOW DATABASES;

USE Course_Mg;

CREATE TABLE IF NOT EXISTS Course_Mg.teachers(
	teacher_no INT AUTO_INCREMENT PRIMARY KEY,
    teacher_name VARCHAR(100) NOT NULL,
    phone_no VARCHAR(20)
);

CREATE TABLE IF NOT EXISTS Course_Mg.courses(
	course_no INT AUTO_INCREMENT PRIMARY KEY,
    course_name VARCHAR(150) NOT NULL,
    start_date DATE,
    end_date DATE 
);

DROP TABLE IF EXISTS Course_Mg.teachers;
DROP TABLE IF EXISTS Course_Mg.courses;
DROP TABLE IF EXISTS Course_Mg.students;

CREATE TABLE IF NOT EXISTS Course_Mg.students(
	student_no INT AUTO_INCREMENT PRIMARY KEY,
    teacher_no INT NOT NULL,
    course_no INT NOT NULL,
    student_name VARCHAR(100) NOT NULL,
    email VARCHAR(100),
    birth_date DATE,
    FOREIGN KEY (teacher_no) REFERENCES teachers(teacher_no) 
		ON UPDATE CASCADE
		ON DELETE RESTRICT,
	FOREIGN KEY (course_no) REFERENCES courses(course_no)
		ON UPDATE CASCADE
		ON DELETE RESTRICT
);


DESCRIBE Course_Mg.teachers;
DESCRIBE Course_Mg.courses;
DESCRIBE Course_Mg.students;

START TRANSACTION;

INSERT INTO teachers (teacher_name, phone_no) VALUES
	("Сергій Бешкет", '+380501112233'),
    ("Ольга Іванова", '+380674445566'),
    ("Дмитро Петров", '+380937778899'),
    ("Олена Коваленко", '+380509990011'),
    ("Олександр Бондар", '+380672223344'),
    ("Анна Мороз", '+380935556677'),
    ("Віктор Ткаченко", '+380508889900');
    
INSERT INTO courses (course_name, start_date, end_date) VALUES
	("Excel", '2026-01-10', '2026-03-10'),
    ("Power BI", '2026-02-15', '2026-04-15'),
    ("SQL", '2026-03-01', '2026-05-01'),
	("Python", '2026-04-10', '2026-06-10'),
    ("Data Science", '2026-05-01', '2026-07-25'),
    ("Web Designe", '2026-05-10', '2026-07-20'),
    ("QA Manual", '2026-06-01', '2026-07-15');
    
INSERT INTO students (teacher_no, course_no, student_name, email, birth_date) VALUES
	(1, 1, "Андрій Мельник", "andriy@email.com", '2004-05-12'),
    (1, 2, "Віктор Бондар", "viktor@email.com", '2003-08-22'),
    (2, 1, "Олена Кравченко", "olena@email.com", '2005-02-15'),
    (2, 3, "Дмитро Іванов", "dmitro@email.com", '2002-11-30'),
    (3, 2, "Софія Лисенко", "sofia@email.com", '2004-01-05'),
    (3, 3, "Максим Ткачук", "maksym@email.com", '2003-06-18'),
    (1, 2, "Анна Попова", "anna@email.com", '2005-09-10');
    
COMMIT;

SELECT*
FROM teachers;
SELECT*
FROM courses;
SELECT*
FROM students;


SELECT 
		t.teacher_no,
		t.teacher_name,
        COUNT(st.student_no) AS students_count
FROM course_mg.teachers t
LEFT JOIN course_mg.students st
	ON t.teacher_no = st.teacher_no
GROUP BY t.teacher_no,
		 t.teacher_name;

START TRANSACTION;
INSERT INTO students (teacher_no, course_no, student_name, email, birth_date)
SELECT 	teacher_no, course_no, student_name, email, birth_date
FROM course_mg.students
LIMIT 3;
COMMIT;

SELECT *
FROM course_mg.students;   

SELECT
      teacher_no,
      course_no,
      student_name,
      email,
      birth_date,
      COUNT(*) as duplicate_count
FROM course_mg.students
GROUP BY 
		teacher_no,
        course_no,
        student_name,
        email,
        birth_date
HAVING 
       COUNT(*) > 1;
