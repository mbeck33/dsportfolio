/*
	Author	: Matt Beck
	Course	: IST659 M400
	Term		: October, 2019
	*/

/*
	Drop the tables first, if they exist
	Dropped in reverse order of creation to avoid any problems with
	foreign key references
	Using SQL Server 2016 DROP method
*/
DROP TABLE IF EXISTS forecast
DROP TABLE IF EXISTS metric_value
DROP TABLE IF EXISTS benchmark
DROP TABLE IF EXISTS metric_business_question_list
DROP TABLE IF EXISTS metric
DROP TABLE IF EXISTS role_business_question_list
DROP TABLE IF EXISTS business_question
DROP TABLE IF EXISTS [user]
DROP TABLE IF EXISTS [role]
DROP FUNCTION IF EXISTS max_benchmark
DROP FUNCTION IF EXISTS derive_latest_value
DROP VIEW IF EXISTS bq_role_user_counts
DROP VIEW IF EXISTS business_questions_by_role
DROP VIEW IF EXISTS company_performance
DROP VIEW IF EXISTS forecast_actual_comparison
DROP VIEW IF EXISTS bq_employee_lookup

/*
Creating Tables for Database
*/

-- Creating the Role table
CREATE TABLE [role] (
	--Columns for the Role table
	role_id int identity,
	role_name varchar(25) not null,
	--Constraints on the role Table
	CONSTRAINT PK_role PRIMARY KEY (role_id),
	CONSTRAINT U1_role UNIQUE(role_name)
)
--End Creating the Role Table
GO

-- Creating the User table
CREATE TABLE [user] (
	--Columns for the User table
	user_id int identity,
	name varchar(25) not null,
  role_id int not null,
	--Constraints on the User Table
	CONSTRAINT PK_user PRIMARY KEY (user_id),
  CONSTRAINT FK1_user FOREIGN KEY (role_id) REFERENCES role(role_id)
)
--End Creating the User Table
GO
-- Creating the business_question table
CREATE TABLE business_question (
	--Columns for the Role table
	business_question_id int identity,
	question varchar(100) not null,
	--Constraints on the role Table
	CONSTRAINT PK_business_question PRIMARY KEY (business_question_id),
	CONSTRAINT U1_question UNIQUE(question)
)
--End Creating the business question Table
GO
-- Creating the role_business_question_list table
CREATE TABLE role_business_question_list (
	--Columns for the role_business_question_list table
	role_business_question_id int identity,
	business_question_id int not null,
  role_id int not null,
	--Constraints on the role_business_question_list Table
	CONSTRAINT PK_role_business_question_list PRIMARY KEY (role_business_question_id),
  CONSTRAINT FK1_role_business_question_list FOREIGN KEY (business_question_id) REFERENCES business_question(business_question_id),
  CONSTRAINT FK2_role_business_question_list FOREIGN KEY (role_id) REFERENCES role(role_id)
)
--End Creating the role_business_question_list table
GO
--Creating the metric table
CREATE TABLE metric (
  metric_id int identity,
  metric varchar(30) not null,
  description varchar(150),
  direction varchar(5),
  population varchar(25),
  data_steward varchar(25),
  reference varchar(50),
  CONSTRAINT PK_metric PRIMARY KEY (metric_id),
  CONSTRAINT U1_metric UNIQUE(metric)
);

--End Creating the metric Table
GO
-- Creating the metric_business_question_list table
CREATE TABLE metric_business_question_list (
	--Columns for the metric_business_question_list table
	metric_business_question_id int identity,
	business_question_id int not null,
  metric_id int not null,
	--Constraints on the metric_business_question_list Table
	CONSTRAINT PK_metric_business_question_list PRIMARY KEY (metric_business_question_id),
  CONSTRAINT FK1_metric_business_question_list FOREIGN KEY (business_question_id) REFERENCES business_question(business_question_id),
  CONSTRAINT FK2_metric_business_question_list FOREIGN KEY (metric_id) REFERENCES metric(metric_id)
)
--End Creating the role_business_question_list table
GO
--Creating the metric_value table
CREATE TABLE metric_value (
  --Columns for metric value table
  metric_value_id int identity,
  value decimal(3,2) not null,
  entry_date datetime default GetDate(),
  period datetime not null,
	metric_id int not null,
  --Constraints on the metric_value table
  CONSTRAINT PK_metric_value PRIMARY KEY (metric_value_id),
	CONSTRAINT FK1_metric_value FOREIGN KEY (metric_id) REFERENCES metric(metric_id)
)
--End Creating the metric_value table
GO
--Creating the benchmark table
CREATE TABLE benchmark (
  --Columns for benchmark table
  benchmark_id int identity,
  benchmark decimal(5,2) not null,
  entry_date datetime default GetDate(),
  valid_from datetime,
  valid_to datetime,
	metric_id int not null,
  --Constraints on the benchmark table
  CONSTRAINT PK_benchmark PRIMARY KEY (benchmark_id),
	CONSTRAINT FK1_benchmark FOREIGN KEY (metric_id) REFERENCES metric(metric_id)
)
--End Creating the benchmark table
GO
--Creating the forecast table
CREATE TABLE forecast (
  --Columns for forecast table
  forecast_id int identity,
  forecast decimal(5,2) not null,
	period datetime,
  entry_date datetime default GetDate(),
  valid_from datetime,
  valid_to datetime,
	metric_id int not null,
  --Constraints on the forecast table
  CONSTRAINT PK_forecast PRIMARY KEY (forecast_id),
	CONSTRAINT FK1_forecast FOREIGN KEY (metric_id) REFERENCES metric(metric_id)
)
--End Creating the forecast table
GO

--Functions

--Create function for counting the number of roles based on a business question (or abstract to allow the user to include table name)
CREATE FUNCTION bq_count_roles(@bqID int)
RETURNS int AS
BEGIN
    DECLARE @returnValue int --matches the function's return type

    /*
        Get the count of roles for the provided question and
        assign that value to @returnValue.
		*/
    SELECT @returnValue = COUNT(DISTINCT role_id) FROM role_business_question_list rbq
    WHERE rbq.business_question_id = @bqID

    --Return @returnValue to the calling code.
    RETURN @returnValue
END
GO

--Create function for counting # of Users based on business question provided
CREATE FUNCTION bq_count_users(@bqID int)
RETURNS int AS
BEGIN
    DECLARE @returnValue int --matches the function's return type

    /*
        Get the count of users for the provided question and
        assign that value to @returnValue.
		*/
    SELECT @returnValue = COUNT(DISTINCT u.user_id) FROM role_business_question_list rbq
		JOIN [role] r ON rbq.role_id=r.role_id
		JOIN [user] u ON u.role_id=r.role_id
		WHERE rbq.business_question_id = @bqID

    --Return @returnValue to the calling code.
    RETURN @returnValue
END
GO
--Create function for pulling the most recent value for a given metric
CREATE FUNCTION derive_latest_value(@metric_id int)
RETURNS decimal(5,2) AS --COUNT is an integer, so shall it be returned
BEGIN
	DECLARE @returnValue decimal(5,2) --match function return type
 	DECLARE @max_period datetime
    select @max_period = MAX(period) from metric_value WHERE metric_id = @metric_id;
	/*
	Pull the latest value from the metrics table, with the ID provided.
	*/
	WITH CTE_latest_value
AS
(
	SELECT
		mv.*,
		ROW_NUMBER() OVER(PARTITION BY mv.metric_id ORDER BY IIF(mv.period >=@max_period,1,2) ASC) rnk
	FROM
		metric_value mv
)
 SELECT @returnValue = value FROM CTE_latest_value WHERE rnk = 1 and metric_id = @metric_id
	--Return @returnValue to the calling code.
	RETURN @returnValue
END
GO
--Create function for pulling the most recent benchmark for a given metric
CREATE FUNCTION max_benchmark(@metric_id int)
RETURNS decimal(5,2) AS --COUNT is an integer, so shall it be returned
BEGIN
	DECLARE @returnValue decimal(5,2) --match function return type

	/*
		Collect the maximum benchmark value, given the provided metric ID
		and assign that to the return value.
	*/
	SELECT @returnValue = MAX(benchmark) FROM benchmark
	WHERE benchmark.metric_id = @metric_id and valid_to IS NULL

	--Return @returnValue to the calling code.
	RETURN @returnValue
END
GO
--Create function for pulling the predicted forecast for a given metric
CREATE FUNCTION next_forecast(@metric_id int)
RETURNS decimal(5,2) AS --COUNT is an integer, so shall it be returned
BEGIN
	DECLARE @returnValue decimal(5,2) --match function return type
 	DECLARE @next_forecast_period datetime
    select @next_forecast_period = MIN(period) from forecast f
		WHERE metric_id = @metric_id and period > GETDATE();
	/*
		Collect the next upcoming forecast, given the provided metric ID
		and assign that to the return value.
	*/
WITH CTE_latest_value
AS
(
SELECT
	mv.*,
	ROW_NUMBER() OVER(PARTITION BY mv.metric_id ORDER BY IIF(mv.period >=@max_period,1,2) ASC) rnk
FROM
	metric_value mv
)
SELECT @returnValue = value FROM CTE_latest_value WHERE rnk = 1 and metric_id = @metric_id

	--Return @returnValue to the calling code.
	RETURN @returnValue
END
GO
--Stored Procedures
/*
 Stored Procedure for updating a metric value
 Stored Procedure for updating a benchmark value
 Stored Procedure for updating a forecast
 Stored Procedure for updating a role name
 Stored Procedure for updating a user name
 Stored Procedure for updating a business question
 Stored Procedure for adding a new user
 Stored Procedure for adding a new role
 Stored Procedure for adding a new metric
 Stored Procedure for adding a new metric value
 Stored Procedure for adding a new benchmark
 Stored Procedure for adding a new forecast
 Stored Procedure for deleting a metric value
 Stored Procedure for deleting a user
 Stored Procedure for deleting a role
 Stored Procedure for deleting a business question
*/
--Create Stored Procedure for updating a metric value
CREATE PROCEDURE update_metric_value(@metric_id int, @period datetime, @value decimal(5,2))
AS
BEGIN
    UPDATE metric_value SET [value] = @value
    WHERE metric_id = @metric_id AND period = @period
END
GO

--Create Stored Procedure for updating an existing benchmark value, in the case of entry error.
CREATE PROCEDURE update_existing_benchmark_value(@metric_id int, @period datetime, @benchmark decimal(5,2))
AS
BEGIN
    UPDATE benchmark SET [value] = @value
    WHERE metric_id = @metric_id AND period = @period
END
GO
--Create Stored Procedure for updating a forecast, in case of entry error.
CREATE PROCEDURE update_existing_forecast_value(@metric_id int, @period datetime, @forecast decimal(5,2))
AS
BEGIN
    UPDATE forecast SET [value] = @value
    WHERE metric_id = @metric_id AND period = @period
END
GO
--Create Stored Procedure for updating an existing role name
CREATE PROCEDURE update_role_name(@old_role varchar(25), @new_role varchar(25))
AS
BEGIN
    UPDATE [role] SET role_name = @new_role
    WHERE role_name = @old_role
END
GO
--Create Stored Procedure for updating an existing user name
CREATE PROCEDURE update_user_name(@old_name varchar(25), @new_name varchar(25))
AS
BEGIN
    UPDATE [user] SET name = @new_name
    WHERE name = @old_name
END
GO
--Create Stored Procedure for updating an existing business question
CREATE PROCEDURE update_question(@bq_id int, @new_question_lang varchar(25))
AS
BEGIN
    UPDATE business_question SET question = @new_question_lang
    WHERE name = @old_name
END
GO
--Create Stored Procedure for adding a new forecast
CREATE PROCEDURE add_forecast(@metric_id int, @forecast decimal(5,2), @period datetime, @valid_from datetime = NULL ,@valid_to datetime = NULL) AS
BEGIN
	--Update valid_to timestamp to ensure that the most recent forecast is used
	--in the table
 		UPDATE forecast SET valid_to = GetDate()
		WHERE metric_id = @metric_id and valid_to IS NULL
    --Ensure valid_from timestamp is from today's date.
    SELECT @valid_from = GetDate()
    -- Now we can add the row using an INSERT Statement
    INSERT INTO forecast (metric_id,forecast,period,valid_from,valid_to)
    VALUES(@metric_id,@forecast,@period,@valid_from,@valid_to)

    --Now return the @@identity so the calling code knows where
    --the data ended up
    RETURN @@identity
END
GO
--Create Stored Procedure for adding a new benchmark
CREATE PROCEDURE add_benchmark(@metric_id int, @benchmark decimal(5,2), @valid_from datetime = NULL ,@valid_to datetime = NULL) AS
BEGIN
	--Update valid_to timestamp to ensure that the most recent forecast is used
	--in the table
 		UPDATE benchmark SET valid_to = GetDate()
		WHERE metric_id = @metric_id and valid_to IS NULL
    --Ensure valid_from timestamp is from today's date.
    SELECT @valid_from = GetDate()
    -- Now we can add the row using an INSERT Statement
    INSERT INTO benchmark (metric_id,benchmark,valid_from,valid_to)
    VALUES(@metric_id,@benchmark,@valid_from,@valid_to)

    --Now return the @@identity so the calling code knows where
    --the data ended up
    RETURN @@identity
END
GO
--Create Stored Procedure for adding a new user
CREATE PROCEDURE add_new_user(@name varchar(25), @role_name varchar(20)) AS
BEGIN
		DECLARE role_id INT
 		SELECT @role_id = role_id FROM [role] WHERE role_name=@role_name
    -- Now we can add the row using an INSERT Statement
    INSERT INTO [user] (name, role_id)
    VALUES(@name, @role_id)

    --Now return the @@identity so the calling code knows where
    --the data ended up
    RETURN @@identity
END
GO
--Create Stored Procedure for adding a new role
CREATE PROCEDURE add_new_role(@role_name varchar(25)) AS
BEGIN
    --Adding the row using an INSERT Statement
    INSERT INTO [role] (role_name)
    VALUES(@role_name)

    --Now return the @@identity so the calling code knows where
    --the data ended up
    RETURN @@identity
END
GO
--Create Stored Procedure for adding a new business question
CREATE PROCEDURE add_new_question(@question varchar(100)) AS
BEGIN
    --Adding the row using an INSERT Statement
    INSERT INTO business_question (question)
    VALUES(@question)

    --Now return the @@identity so the calling code knows where
    --the data ended up
    RETURN @@identity
END
GO
--Create Stored Procedure for adding a new metric

--Create Stored Procedure for mapping roles to questions
--Create Stored Procedure for mapping questions to metrics
--Create Stored Procedure for deleting a user


--Creating Views
/*
View for Count of roles, users per Business Question
View for List of business questions asked by a given roles
View for averages of metrics
View for metric, value, benchmark, forecast
View for establishing available ranges for each metric
*/
--

--View 1 - How many roles and users are associated with the available business questions?

--Creating View for Counts of roles, users
CREATE VIEW bq_role_user_counts AS (
SELECT question
    , dbo.bq_count_roles(bq.business_question_id) as role_count
		, dbo.bq_count_users(bq.business_question_id) as user_count
    FROM business_question bq
)
GO
--View 2 - What are the questions asked by a given business role?
--Creating View for List of Business Questions
CREATE VIEW business_questions_by_role AS (
	SELECT role_name
    		, question as questions_asked
		FROM business_question bq
		JOIN  role_business_question_list rbq ON rbq.business_question_id=bq.business_question_id
		JOIN [role] r ON rbq.role_id=r.role_id
		--WHERE r.role_name='Executive'
)
GO
--View 3 - What are the rolling averages for each metric, listed by their associated business question?
--Creating View 3
CREATE VIEW company_performance AS (
	SELECT question
        ,m.metric
				, AVG(value) as overall_value
				, dbo.max_benchmark(m.metric_id) as overall_benchmark
				, AVG(dbo.max_benchmark(m.metric_id) - value) as difference_from_benchmark
	FROM metric_value mv
	JOIN metric m ON m.metric_id=mv.metric_id
	JOIN metric_business_question_list mbq ON m.metric_id=mbq.metric_id
    JOIN business_question bq on bq.business_question_id=mbq.business_question_id
	GROUP BY question,metric,m.metric_id
)
GO
--View 4 - How did our actuals compare to our forecast?
--Creating View 4
CREATE VIEW forecast_actual_comparison AS (
	SELECT m.metric
				,	AVG(f.forecast) as forecast_average
				, AVG(mv.value) actual_average
				,AVG(mv.value - f.forecast)*100 as difference_from_forecast
	FROM metric m
	JOIN metric_value mv ON m.metric_id=mv.metric_id
	JOIN forecast f ON f.metric_id = m.metric_id AND mv.period = f.period
    GROUP BY metric
)
GO
--View 5 -Which employees are responsible for which business questions?
-- Creating View 5
CREATE VIEW bq_employee_lookup AS (
	SELECT
		u.name
    ,bq.question
		FROM business_question bq
		JOIN role_business_question_list rbq ON rbq.business_question_id=bq.business_question_id
		JOIN [role] r ON rbq.role_id=r.role_id
		JOIN [user] u ON u.role_id=r.role_id
)
GO

/*
DML Section
*/
--Insert into role table
INSERT INTO [role]
(role_name)
VALUES
('Executive'),
('Manager'),
('Analyst'),
('Staff')
--End role table insertion
GO
--Insert into user table
INSERT INTO [user]
(name,role_id)
VALUES
('Haleigh Musslewhite',1),
('Barbi Barbary',2),
('Ignace Veldens',3),
('Schuyler Beldum',4),
('Pauli Wherry',1),
('Caryl Jarrell',2),
('Brodie Auten',3),
('Alane Poveleye',4),
('Skylar Claw',1),
('Corny Immings',2),
('Aluin Rayer',4),
('Aluino Sheraton',2),
('Krystyna Crocetti',3),
('Ayn Jecks',4),
('Karrah Eisenberg',2),
('Cullie Gehrts',4),
('Arv Busby',4),
('Thorny Arp',4),
('Olly Savory',4),
('Clarie Prose',4)
--End role table insertion
GO
--Insert into business question table
INSERT INTO business_question
(question)
VALUES
('At what rate are we generating new leads?'),
('How is the sales funnel performing?'),
('How many visits does our website get?'),
('How are email campaigns performing?'),
('How do our sales forecasts compare to management targets?'),
('What is our total cost of acquisition?'),
('How satisfied are our clients?')
--End business question table insertion
GO
--Insert into role/business question list table
INSERT INTO role_business_question_list
(business_question_id,role_id)
VALUES
(1,1),
(1,2),
(1,3),
(1,4),
(2,1),
(2,2),
(2,3),
(3,2),
(3,3),
(3,4),
(4,2),
(4,3),
(4,4),
(5,1),
(5,3),
(6,1),
(6,3),
(7,1),
(7,3),
(7,4)
--End role/business question list table insertion
GO
--Insert into metric table
INSERT INTO metric
(metric,description,direction,population,data_steward,reference)
VALUES
('Lead Generation Rate','Velocity of new leads into the sales funnel','Up','Leads','Sales Operations','https://referencepage.io'),
('Sales Funnel Performance','Rate of Sales made relative to previous year','Up','','Sales Operations','https://bloglines.com/dui/proin/leo/odio.xml?partu'),
('Quarterly Website Visits','# of Website visits in a quarter','Up','Web Visitors','Web Sales','http://oakley.com/felis/sed/interdum/venenatis.xml'),
('Website Visit Return Rate','# of users who return to the website','','Web Visitors','Web Sales','https://purevolume.com/morbi.json?accumsan=neque&t'),
('Forecast-to-Target Ratio','Ratio of our forecasted performance relative to company targets','Down','','Sales Analytics','https://storify.com/id/consequat/in/consequat/ut/n'),
('TCA Rate','Rate of Total Cost of acquiring a sale','Down','','Sales Analytics','http://amazonaws.com/ut/massa.jpg?semper=consectet'),
('Client Satisfaction','% of clients who report they are satisfied with their product','Up','',NULL,'https://bluehost.com/elementum/nullam/varius/nulla'),
('Email Open Rate','% of sent emails that were opened','Up',NULL,'','https://parallels.com/posuere/cubilia/curae/donec/'),
('Email Click Rate','% of sent emails where user clicked the link','Up','Email List','',NULL)

--End metric table insertion
GO
--Insert into metric/business question list table
INSERT INTO metric_business_question_list
(business_question_id,metric_id)
VALUES
(1,1),
(2,2),
(3,3),
(3,4),
(4,8),
(4,9),
(5,5),
(6,6),
(7,7)
--End metric/business question list table insertion
GO
--Insert into metric value table
INSERT INTO metric_value
(value,period,metric_id)
VALUES
(0.51,'2019-01-01 05:00:00',1),
(0.99,'2019-02-01 05:00:00',1),
(0.57,'2019-03-01 05:00:00',1),
(0.51,'2019-04-01 05:00:00',1),
(0.69,'2019-05-01 05:00:00',1),
(0.75,'2019-06-01 05:00:00',1),
(0.14,'2019-07-01 05:00:00',1),
(0.93,'2019-08-01 05:00:00',1),
(0.71,'2019-09-01 05:00:00',1),
(0.55,'2019-01-01 05:00:00',2),
(0.96,'2019-02-01 05:00:00',2),
(0.67,'2019-03-01 05:00:00',2),
(0.78,'2019-04-01 05:00:00',2),
(0.62,'2019-05-01 05:00:00',2),
(0.33,'2019-06-01 05:00:00',2),
(0.64,'2019-07-01 05:00:00',2),
(0.26,'2019-08-01 05:00:00',2),
(0.14,'2019-09-01 05:00:00',2),
(0.46,'2019-01-01 05:00:00',3),
(0.93,'2019-02-01 05:00:00',3),
(0.87,'2019-03-01 05:00:00',3),
(0.35,'2019-04-01 05:00:00',3),
(0.65,'2019-05-01 05:00:00',3),
(0.54,'2019-06-01 05:00:00',3),
(0.48,'2019-07-01 05:00:00',3),
(0.61,'2019-08-01 05:00:00',3),
(0.75,'2019-09-01 05:00:00',3),
(0.88,'2019-01-01 05:00:00',4),
(0.13,'2019-02-01 05:00:00',4),
(0.11,'2019-03-01 05:00:00',4),
(0.18,'2019-04-01 05:00:00',4),
(0.95,'2019-05-01 05:00:00',4),
(0.47,'2019-06-01 05:00:00',4),
(0.55,'2019-07-01 05:00:00',4),
(0.68,'2019-08-01 05:00:00',4),
(0.79,'2019-09-01 05:00:00',4),
(0.85,'2019-01-01 05:00:00',5),
(0.47,'2019-02-01 05:00:00',5),
(0.35,'2019-03-01 05:00:00',5),
(0.28,'2019-04-01 05:00:00',5),
(0.52,'2019-05-01 05:00:00',5),
(0.66,'2019-06-01 05:00:00',5),
(0.69,'2019-07-01 05:00:00',5),
(0.52,'2019-08-01 05:00:00',5),
(0.49,'2019-09-01 05:00:00',5),
(0.93,'2019-01-01 05:00:00',6),
(0.18,'2019-02-01 05:00:00',6),
(0.11,'2019-03-01 05:00:00',6),
(0.14,'2019-04-01 05:00:00',6),
(0.12,'2019-05-01 05:00:00',6),
(0.86,'2019-06-01 05:00:00',6),
(0.36,'2019-08-01 05:00:00',6),
(0.58,'2019-08-01 05:00:00',6),
(0.29,'2019-09-01 05:00:00',6),
(0.99,'2019-01-01 05:00:00',7),
(0.04,'2019-02-01 05:00:00',7),
(0.06,'2019-03-01 05:00:00',7),
(0.17,'2019-04-01 05:00:00',7),
(0.48,'2019-05-01 05:00:00',7),
(0.78,'2019-06-01 05:00:00',7),
(0.09,'2019-07-01 05:00:00',7),
(0.49,'2019-08-01 05:00:00',7),
(0.77,'2019-09-01 05:00:00',7),
(0.84,'2019-01-01 05:00:00',8),
(0.57,'2019-02-01 05:00:00',8),
(0.19,'2019-03-01 05:00:00',8),
(0.09,'2019-04-01 05:00:00',8),
(0.25,'2019-05-01 05:00:00',8),
(0.87,'2019-06-01 05:00:00',8),
(0.06,'2019-07-01 05:00:00',8),
(0.75,'2019-08-01 05:00:00',8),
(0.09,'2019-09-01 05:00:00',8),
(0.35,'2019-01-01 05:00:00',9),
(0.61,'2019-02-01 05:00:00',9),
(0.68,'2019-03-01 05:00:00',9),
(0.25,'2019-04-01 05:00:00',9),
(0.76,'2019-05-01 05:00:00',9),
(0.77,'2019-06-01 05:00:00',9),
(0.17,'2019-07-01 05:00:00',9),
(0.61,'2019-08-01 05:00:00',9),
(0.36,'2019-09-01 05:00:00',9)
--End metric value table insertion
GO
--Insert into benchmark table
INSERT INTO benchmark
(benchmark,valid_from,valid_to,metric_id)
VALUES
(0.6,'2019-01-01 05:00:00',NULL,1),
(0.8,'2019-01-01 05:00:00',NULL,2),
(0.5,'2019-01-01 05:00:00',NULL,3),
(0.4,'2019-01-01 05:00:00','2019-05-31 05:00:00',4),
(0.6,'2019-06-01 05:00:00',NULL,4),
(0.65,'2019-01-01 05:00:00',NULL,5),
(0.72,'2019-01-01 05:00:00',NULL,6),
(0.60,'2019-01-01 05:00:00','2019-06-30 05:00:00',7),
(0.70,'2019-01-01 05:00:00',NULL,7),
(0.75,'2019-01-01 05:00:00',NULL,8),
(0.38,'2019-01-01 05:00:00',NULL,9)
--End benchmark table insertion
GO
--Insert into forecast table
INSERT INTO forecast
(forecast,period,valid_from,valid_to,metric_id)
VALUES
(0.91,'2019-01-01 05:00:00','2019-01-01 05:00:00',NULL,1),
(0.12,'2019-04-01 05:00:00','2019-01-01 05:00:00',NULL,1),
(0.56,'2019-07-01 05:00:00','2019-01-01 05:00:00',NULL,1),
(0.96,'2019-10-01 05:00:00','2019-01-01 05:00:00',NULL,1),
(0.21,'2019-01-01 05:00:00','2019-01-01 05:00:00',NULL,2),
(0.72,'2019-04-01 05:00:00','2019-01-01 05:00:00',NULL,2),
(0.02,'2019-07-01 05:00:00','2019-01-01 05:00:00',NULL,2),
(0.39,'2019-10-01 05:00:00','2019-01-01 05:00:00',NULL,2),
(0.76,'2019-01-01 05:00:00','2019-01-01 05:00:00',NULL,3),
(0.01,'2019-04-01 05:00:00','2019-01-01 05:00:00',NULL,3),
(0.88,'2019-07-01 05:00:00','2019-01-01 05:00:00',NULL,3),
(0.78,'2019-10-01 05:00:00','2019-01-01 05:00:00',NULL,3),
(0.5,'2019-01-01 05:00:00','2019-01-01 05:00:00',NULL,4),
(0.17,'2019-04-01 05:00:00','2019-01-01 05:00:00',NULL,4),
(0.49,'2019-07-01 05:00:00','2019-01-01 05:00:00',NULL,5),
(0.49,'2019-10-01 05:00:00','2019-01-01 05:00:00',NULL,5),
(0.32,'2019-01-01 05:00:00','2019-01-01 05:00:00',NULL,5),
(0.61,'2019-04-01 05:00:00','2019-01-01 05:00:00',NULL,5),
(0.97,'2019-07-01 05:00:00','2019-01-01 05:00:00',NULL,6),
(0.56,'2019-10-01 05:00:00','2019-01-01 05:00:00',NULL,6),
(0.7,'2019-01-01 05:00:00','2019-01-01 05:00:00',NULL,6),
(0.72,'2019-04-01 05:00:00','2019-01-01 05:00:00',NULL,6),
(0.48,'2019-07-01 05:00:00','2019-01-01 05:00:00',NULL,7),
(0.45,'2019-10-01 05:00:00','2019-01-01 05:00:00',NULL,7),
(0.09,'2019-01-01 05:00:00','2019-01-01 05:00:00',NULL,7),
(0.5,'2019-04-01 05:00:00','2019-01-01 05:00:00',NULL,7),
(0.4,'2019-07-01 05:00:00','2019-01-01 05:00:00',NULL,8),
(0.62,'2019-10-01 05:00:00','2019-01-01 05:00:00',NULL,8),
(0.05,'2019-01-01 05:00:00','2019-01-01 05:00:00',NULL,8),
(0.74,'2019-04-01 05:00:00','2019-01-01 05:00:00',NULL,8),
(0.89,'2019-07-01 05:00:00','2019-01-01 05:00:00',NULL,9),
(0.68,'2019-10-01 05:00:00','2019-01-01 05:00:00',NULL,9)
--End benchmark table insertion
GO

--Demonstrate Stored Procedures at work:
/*
1.

Update Metric values
*/

--Updating Existing Metrics
EXEC update_metric_value 1, '2019-08-01 05:00:00', 0.63
--Adding a new forecast
DECLARE @new_forecast_id INT
EXEC @new_forecast_id = add_forecast 1, 0.85, '2019-10-01 05:00:00'
SELECT * FROM forecast WHERE forecast_id = @new_forecast_id
GO
--Adding a new user
DECLARE @new_user_id INT
EXEC @new_user_id = add_new_user 'Wendy Williams', 'Manager'
SELECT * FROM [user] WHERE user_id = @new_user_id
GO
--Adding a new role
DECLARE @new_role_id INT
EXEC @new_role_id = add_new_role 'Senior Staff'
SELECT * FROM [role] WHERE role_id = @new_role_id
GO
--Adding a new question
DECLARE @new_question_id INT
EXEC @new_question_id = add_new_question 'How is our employee productivity?'
SELECT * FROM business_question WHERE question_id = @new_question_id
GO
--Deleting a user

/*
There are only a select few use cases for deletion in this database - most values
should only be updated to ensure the business can track what has been done
before. Historical data is *important*.
*/

--Demonstrate Views
--1. How many roles and users are linked to a given business question?
SELECT * FROM bq_role_user_counts
--2. Which business questions does a particular role need to ask?
SELECT * FROM business_questions_by_role ORDER BY role_name;
--3. What is our current company performance, based on the questions we care about, and relative to our benchmarks?
SELECT * FROM company_performance ORDER BY difference_from_benchmark DESC;
--4. For each of our metrics, how did our actuals compare with our forecasts?
SELECT * FROM forecast_actual_comparison ORDER BY difference_from_forecast DESC;
--5. Which employees (users) can answer a given business question?
SELECT * FROM bq_employee_lookup ORDER BY name;
