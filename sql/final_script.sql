drop database if exists food_ordering_db;

create database if not exists food_ordering_db;

use food_ordering_db;

SET SQL_SAFE_UPDATES = 0;

-- --------------------
-- Create table 1.1.1--
-- --------------------

CREATE TABLE ACCOUNT (
    ID INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(100) NOT NULL
);


CREATE TABLE CUSTOMER (
    ID INT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100),
    exchange_points INT DEFAULT 0,
    phone_number VARCHAR(10) UNIQUE NOT NULL,
    address VARCHAR(255) NOT NULL,
    birthdate DATE NOT NULL,
    card_number VARCHAR(30) UNIQUE NOT NULL,
    bank_name VARCHAR(100),
    FOREIGN KEY (ID) REFERENCES ACCOUNT(ID) ON DELETE CASCADE
);

CREATE TABLE RESTAURANT (
    ID INT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    phone_number VARCHAR(10) UNIQUE NOT NULL,
    address VARCHAR(255) NOT NULL,
    open_hour TIME,
    close_hour TIME,
    FOREIGN KEY (ID) REFERENCES ACCOUNT(ID) ON DELETE CASCADE
);

CREATE TABLE DISCOUNT_FROM_RESTAURANT (
    code VARCHAR(100) UNIQUE PRIMARY KEY,
    usageLimit INT,
    used_Count INT NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    value INT NOT NULL,
    RID INT NOT NULL,
    FOREIGN KEY (RID) REFERENCES RESTAURANT(ID),
    CHECK (value > 0),
    CHECK (usageLimit >= 0 AND used_Count <= usageLimit),
    CHECK (end_date = DATE_ADD(start_date, interval 7 day))
);

CREATE TABLE DISCOUNT_FROM_EXCHANGE_POINT (
    code VARCHAR(100) UNIQUE PRIMARY KEY,
    exchange_date DATETIME NOT NULL,
    end_date DATETIME NOT NULL,
    value INT NOT NULL,
    CID INT NOT NULL,
    FOREIGN KEY (CID) REFERENCES CUSTOMER(ID) ON DELETE CASCADE,
    CHECK (value > 0)
);


CREATE TABLE CATEGORY (
    ID INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    RID INT NOT NULL,
    FOREIGN KEY (RID) REFERENCES RESTAURANT(ID) ON DELETE CASCADE
);

CREATE TABLE FOOD_ITEM (
    ID INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    price INT NOT NULL,
    image VARCHAR(256),
    categoryID INT NOT NULL,
    FOREIGN KEY (categoryID) REFERENCES CATEGORY(ID) ON DELETE CASCADE,
    CHECK (price > 0)
);

CREATE TABLE FOOD_DELIVER (
    ID INT AUTO_INCREMENT PRIMARY KEY,
    phone_number VARCHAR(20) UNIQUE NOT NULL,
    vehicle_number VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL
);

CREATE TABLE FOOD_ORDER (
    ID INT AUTO_INCREMENT PRIMARY KEY,
    Payment_method ENUM('CARD', 'CASH'),
    address VARCHAR(255) NOT NULL,
    order_status ENUM('pending', 'confirmed', 'delivered', 'cancelled') DEFAULT 'pending',
    order_time_stamp TIMESTAMP NOT NULL,
    review TEXT,
    rating INT,
	-- gía tổng
	orderCost INT NOT NULL DEFAULT 0,
    ship_status ENUM('delivering', 'delivered'),
    get_status ENUM('in_process', 'finished', 'cancelled'),
    delivery_fee INT NOT NULL,
    CID INT NOT NULL,
    RID INT NOT NULL,
    FDID INT NOT NULL,
    FOREIGN KEY (CID) REFERENCES CUSTOMER(ID) ON DELETE CASCADE,
    FOREIGN KEY (RID) REFERENCES RESTAURANT(ID) ON DELETE CASCADE,
    FOREIGN KEY (FDID) REFERENCES FOOD_DELIVER(ID) ON DELETE CASCADE,
    CHECK (rating >= 1 AND rating <= 5),
    CHECK (delivery_fee >= 0)
);

CREATE TABLE `use` (
    CID INT NOT NULL,
    DFRcode VARCHAR(100) NOT NULL,
    PRIMARY KEY (CID, DFRcode),
    FOREIGN KEY (CID) REFERENCES CUSTOMER(ID) ON DELETE CASCADE,
    FOREIGN KEY (DFRcode) REFERENCES DISCOUNT_FROM_RESTAURANT(code) ON DELETE CASCADE
);

CREATE TABLE `contain` (
    FOID INT NOT NULL,
    FIID INT NOT NULL,
    quantity INT NOT NULL,
    PRIMARY KEY (FOID, FIID),
    FOREIGN KEY (FOID) REFERENCES FOOD_ORDER(ID) ON DELETE CASCADE,
    FOREIGN KEY (FIID) REFERENCES FOOD_ITEM(ID) ON DELETE CASCADE,
    CHECK (quantity > 0)
);

CREATE TABLE apply_for (
    DFRcode VARCHAR(100) NOT NULL,
    FOID INT NOT NULL,
    PRIMARY KEY (DFRcode, FOID),
    FOREIGN KEY (DFRcode) REFERENCES DISCOUNT_FROM_RESTAURANT(code) ON DELETE CASCADE,
    FOREIGN KEY (FOID) REFERENCES FOOD_ORDER(ID) ON DELETE CASCADE
);


CREATE TABLE discount_point_apply_for (
    DFEPcode VARCHAR(100) NOT NULL,
    FOID INT NOT NULL,
    PRIMARY KEY (DFEPcode, FOID),
    FOREIGN KEY (DFEPcode) REFERENCES DISCOUNT_FROM_EXCHANGE_POINT(code) ON DELETE CASCADE,
    FOREIGN KEY (FOID) REFERENCES FOOD_ORDER(ID) ON DELETE CASCADE
);

select * from food_order;
select * from restaurant;

-- ---------------
-- TRIGGER 1.1.1--
-- ---------------
DELIMITER $$
-- TRIGGER 1
CREATE TRIGGER check_food_order_restaurant
BEFORE INSERT ON food_ordering_db.contain
FOR EACH ROW
BEGIN
    DECLARE res_id INT; 
    -- Retrieve the restaurant ID of the food order
    SELECT RID INTO res_id FROM food_ordering_db.food_order WHERE ID = NEW.FOID;
    
    -- Check if the restaurant ID of the FOOD_ITEM matches the FOOD_ORDER
    IF NOT EXISTS (
        SELECT 1
        FROM food_ordering_db.food_item FI
        JOIN food_ordering_db.category C ON FI.categoryID = C.ID
        WHERE FI.ID = NEW.FIID AND C.RID = res_id
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Food item does not belong to the same restaurant as the food order.';
    END IF;
END$$
DELIMITER ;



-- TRIGGER 2
DELIMITER $$
-- TRIGGER 2
CREATE TRIGGER check_restaurant_discount_limit
BEFORE INSERT ON APPLY_FOR 
FOR EACH ROW
BEGIN
    DECLARE total_order_price INT;
    DECLARE restaurant_discount INT;

    -- Calculate the total price of the food order
    SELECT SUM(FI.price * C.quantity)
    INTO total_order_price
    FROM CONTAIN C
    JOIN FOOD_ITEM FI ON C.FIID = FI.ID
    WHERE C.FOID = NEW.FOID;

    -- Get the restaurant discount value
    SELECT DFR.value
    INTO restaurant_discount
    FROM DISCOUNT_FROM_RESTAURANT DFR
    WHERE DFR.code = NEW.DFRcode;
    

    -- Check if the total discount exceeds 30% of the total price
    IF restaurant_discount > total_order_price * 0.30 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'The discount exceeds 30% of the total food order price.';
    END IF;
END$$

DELIMITER ;


-- DELIMITER $$
-- CREATE TRIGGER check_exchange_discount_limit
-- BEFORE INSERT ON DISCOUNT_POINT_APPLY_FOR
-- FOR EACH ROW
-- BEGIN
--     DECLARE total_order_price DECIMAL(10, 2);
--     DECLARE restaurant_discount DECIMAL(10, 2);
--     DECLARE exchange_discount DECIMAL(10, 2);
--     DECLARE total_discount DECIMAL(10, 2);

--     -- Calculate the total price of the food order
--     SELECT SUM(FI.price * C.quantity)
--     INTO total_order_price
--     FROM CONTAIN C
--     JOIN FOOD_ITEM FI ON C.FIID = FI.ID
--     WHERE C.FOID = NEW.FOID;

--     -- Get the restaurant discount value from APPLY_FOR
--     SELECT DFR.value
--     INTO restaurant_discount
--     FROM DISCOUNT_FROM_RESTAURANT DFR
--     JOIN APPLY_FOR A ON DFR.code = A.DFRcode
--     WHERE A.FOID = NEW.FOID;

--     -- Get the exchange discount value from DISCOUNT_FROM_EXCHANGE_POINT
--     SELECT DFEP.value
--     INTO exchange_discount
--     FROM DISCOUNT_FROM_EXCHANGE_POINT DFEP
--     WHERE DFEP.code = NEW.DFEPcode;

--     -- Calculate the total discount (restaurant + exchange point)
--     SET total_discount = restaurant_discount + exchange_discount;

--     -- Check if the total discount exceeds 30% of the total price
--     IF total_discount > total_order_price * 0.30 THEN
--         SIGNAL SQLSTATE '45000'
--         SET MESSAGE_TEXT = 'The total discount exceeds 30% of the total food order price.';
--     END IF;
-- END;
-- $$

-- DELIMITER ;


-- ------------------
-- PROCEDURE 1.2.1 --
-- ------------------
DELIMITER $$
-- PROCEDURE 1: INSERT (phải thêm danh mục trước rồi mới thêm món ăn vô)
CREATE PROCEDURE AddFoodItem(
	IN namefood VARCHAR(255),
    IN pricefood INT,
    IN imagefood VARCHAR(255),
    IN cateId INT
)
BEGIN
	IF (namefood = "") THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'The food name field cannot be blank';
    ELSEIF (pricefood <= 0) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'The food price must be greater 0';
    ELSEIF (NOT EXISTS(SELECT 1 FROM CATEGORY WHERE ID = cateId)) THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'The new category has not been added';
    -- Chèn dữ liệu vào bảng mon_an nếu tất cả các kiểm tra đều vượt qua
    ELSE
        INSERT INTO FOOD_ITEM (
            name, price, image, categoryID
        ) VALUES (
            namefood, pricefood, imagefood, cateId
        );
    END IF;
END$$
DELIMITER ;


-- PROCEDURE 2: DELETE
DELIMITER $$
CREATE PROCEDURE DeleteFoodItem(
	IN idfood INT
)
BEGIN
    -- Kiểm tra nếu mã món ăn không tồn tại
    IF NOT EXISTS (SELECT 1 FROM FOOD_ITEM WHERE ID = idfood) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'The food ID does not exist';
    -- Xóa món ăn nếu mã tồn tại
    ELSE
        DELETE FROM FOOD_ITEM WHERE ID = idfood;
    END IF;
END$$

DELIMITER ;


DELIMITER $$
-- PROCEDURE 3
CREATE PROCEDURE UpdateFoodItem(
	IN idfood INT,
	IN namefood VARCHAR(255),
    IN pricefood INT,
    IN imagefood VARCHAR(255),
    IN cateID INT
)
BEGIN
    -- Kiểm tra nếu mã món ăn không tồn tại
    IF NOT EXISTS (SELECT 1 FROM FOOD_ITEM WHERE ID = idfood) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'The food ID does not exists';
    ELSEIF (pricefood <= 0 ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'The food price must be greater 0';
	ELSEIF NOT EXISTS (SELECT 1 FROM CATEGORY WHERE ID = cateID) THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'The category does not exist';
    ELSE
		UPDATE FOOD_ITEM 
        SET name = namefood, price = pricefood, image = imagefood, categoryID = cateID 
        where ID = idfood;
	END IF;
END$$
DELIMITER ;


-- ----------------
-- TRIGGER 1.2.2 --
-- ----------------
DELIMITER $$

-- TRIGGER 1
CREATE TRIGGER update_customer_exchange_point
AFTER UPDATE ON FOOD_ORDER
FOR EACH ROW
BEGIN
    -- Kiểm tra nếu trạng thái đơn hàng được cập nhật thành 'delivered'
    IF NEW.order_status = 'delivered' AND OLD.order_status = 'confirmed' THEN
        -- Cộng 20 điểm cố định vào exchange_points
        UPDATE CUSTOMER
        SET exchange_points = COALESCE(exchange_points, 0) + 20
        WHERE ID = NEW.CID;
    END IF;
END$$

DELIMITER ;


DELIMITER $$
-- TRIGGER 2
-- EXTRA TRIGGER FOR CALCULATING orderCost not including discount (AFTER INSERT DATA IN CONTAIN)
CREATE TRIGGER update_order_cost_after_insert_contain 
AFTER INSERT ON `contain`
FOR EACH ROW
BEGIN
	DECLARE priceFood INT DEFAULT 0;
    SET priceFood = (SELECT price FROM FOOD_ITEM WHERE ID = NEW.FIID);
	UPDATE FOOD_ORDER
	SET orderCost = priceFood * NEW.quantity + delivery_fee
	WHERE ID = NEW.FOID;
END$$

DELIMITER ;



-- -----------------
-- PROCEDURE 1.2.3--
-- -----------------

-- -----------------------------
-- PROCEDURE 1 :Tất cả các orders có áp dụng discount 
-- -----------------------------
DELIMITER //

CREATE PROCEDURE RetrieveOrdersByCustomerWithDiscounts(
    IN p_CustomerID INT
)
BEGIN
    SELECT 
        FO.ID AS OrderID,
        FO.Payment_method,
        FO.address AS OrderAddress,
        FO.order_status AS OrderStatus,
        FO.order_time_stamp AS OrderTimestamp,
        FO.review,
        FO.rating,
        FO.ship_status AS ShippingStatus,
        FO.get_status AS GetStatus,
        FO.delivery_fee,
        SUM(FI.price * C.quantity) AS TotalOrderPrice,
        
        -- Calculate restaurant discount
        COALESCE((
            SELECT DFR.value
            FROM DISCOUNT_FROM_RESTAURANT DFR
            JOIN APPLY_FOR A ON DFR.code = A.DFRcode
            WHERE A.FOID = FO.ID
        ), 0) AS RestaurantDiscount,
        
        -- Calculate exchange point discount as a fixed value
        COALESCE((
            SELECT DFEP.value
            FROM DISCOUNT_FROM_EXCHANGE_POINT DFEP
            JOIN DISCOUNT_POINT_APPLY_FOR DPAF ON DFEP.code = DPAF.DFEPcode
            WHERE DPAF.FOID = FO.ID
        ), 0) AS ExchangePointDiscount,

        -- Calculate total discount as the sum of restaurant and exchange point discounts
        COALESCE((
            SELECT DFR.value
            FROM DISCOUNT_FROM_RESTAURANT DFR
            JOIN APPLY_FOR A ON DFR.code = A.DFRcode
            WHERE A.FOID = FO.ID
        ), 0) + COALESCE((
            SELECT DFEP.value
            FROM DISCOUNT_FROM_EXCHANGE_POINT DFEP
            JOIN DISCOUNT_POINT_APPLY_FOR DPAF ON DFEP.code = DPAF.DFEPcode
            WHERE DPAF.FOID = FO.ID
        ), 0) AS TotalDiscount
        
    FROM 
        FOOD_ORDER FO
    LEFT JOIN CONTAIN C ON C.FOID = FO.ID
    LEFT JOIN FOOD_ITEM FI ON C.FIID = FI.ID
    WHERE 
        FO.CID = p_CustomerID
        AND (
            EXISTS (
                SELECT 1
                FROM APPLY_FOR A
                JOIN DISCOUNT_FROM_RESTAURANT DFR ON A.DFRcode = DFR.code
                WHERE A.FOID = FO.ID
            )
            OR EXISTS (
                SELECT 1
                FROM DISCOUNT_POINT_APPLY_FOR DPAF
                JOIN DISCOUNT_FROM_EXCHANGE_POINT DFEP ON DPAF.DFEPcode = DFEP.code
                WHERE DPAF.FOID = FO.ID
            )
        )
    GROUP BY 
        FO.ID;
END //


DELIMITER ;




DELIMITER //
-- -----------------------------
-- PROCEDURE 2 : Không xài
-- -----------------------------
DELIMITER //

CREATE PROCEDURE UpdateDiscountUsageAndCheckLimit(
    IN p_FoodOrderID INT
)
BEGIN
    -- Declare variables to hold discount information
    DECLARE v_discount_code VARCHAR(50);
    DECLARE v_used_count INT;
    DECLARE v_usage_limit INT;

    -- Declare handler for no data found in SELECT INTO
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_discount_code = NULL;

    -- Get the discount code, used count, and usage limit
    SELECT DFR.code, DFR.used_Count, DFR.usageLimit
    INTO v_discount_code, v_used_count, v_usage_limit
    FROM DISCOUNT_FROM_RESTAURANT DFR
    JOIN APPLY_FOR AF ON DFR.code = AF.DFRcode
    WHERE AF.FOID = p_FoodOrderID;

    -- If the discount exists, process it
    IF v_discount_code IS NOT NULL THEN
        -- Check if usage limit has been reached or exceeded
        IF v_used_count + 1 >= v_usage_limit THEN
           -- UPDATE DISCOUNT_FROM_RESTAURANT
            -- SET used_Count = NULL, usageLimit = NULL, start_date = NULL, end_date = NULL
            DELETE FROM DISCOUNT_FROM_RESTAURANT WHERE code = v_discount_code;
        END IF;
    END IF;
END //

DELIMITER ;

DELIMITER //

CREATE TRIGGER update_used_count_after_insert_apply_for
AFTER INSERT ON apply_for
FOR EACH ROW
BEGIN
	UPDATE DISCOUNT_FROM_RESTAURANT
    SET used_Count = used_Count + 1
    WHERE code = NEW.DFRcode;
END //
DELIMITER ;

-- **************************************************************
-- PROCEDURE 3 : Xài

DROP PROCEDURE IF EXISTS RetrieveOrdersByCategory;

DELIMITER //

CREATE PROCEDURE RetrieveOrdersByCategory(
    IN p_categoryID INT
)
BEGIN
    SELECT 
        FO.ID AS OrderID,
        FO.order_time_stamp AS OrderTime,
        FO.rating,
        CU.name AS CustomerName,
        SUM(C.quantity) AS TotalItems, 
        FO.order_status AS OrderStatus,
        SUM(C.quantity * FI.price) AS TotalRevenue 
    FROM FOOD_ORDER FO
    JOIN CUSTOMER CU ON FO.CID = CU.ID
    JOIN CONTAIN C ON FO.ID = C.FOID
    JOIN FOOD_ITEM FI ON C.FIID = FI.ID
    WHERE FI.categoryID = p_categoryID
    GROUP BY FO.ID, FO.order_time_stamp, CU.name, FO.order_status, FO.rating
    HAVING TotalItems > 0 
    ORDER BY TotalRevenue DESC;
END //

DELIMITER ;

CALL RetrieveOrdersByCategory(1);
CALL RetrieveOrdersByCategory(2);





-- DROP DATABASE FOOD_ORDERING_DB;


-- -----------------------
-- ADDITIONAL PROCEDURE --
-- -----------------------
DELIMITER $$

CREATE PROCEDURE AddUserAccount (IN inputname VARCHAR(100), IN inputpasswd VARCHAR(100))
BEGIN
	IF (EXISTS (SELECT * FROM ACCOUNT WHERE username = inputname)) THEN SIGNAL SQLSTATE '45000' set message_text = 'Tên đăng nhập đã tồn tại';
    ELSEIF (LENGTH(inputpasswd) < 8) THEN SIGNAL SQLSTATE '45000' set message_text = 'Vui lòng nhập mật khẩu ít nhất 8 kí tự';
    ELSE 
		INSERT INTO ACCOUNT (username, password) VALUES (inputname, inputpasswd);
	END IF;
END $$

DELIMITER ;


DELIMITER $$
CREATE PROCEDURE AddCustomer (
    IN usernameCustomer VARCHAR(100),
    IN nameCustomer VARCHAR(100), 
    IN emailCustomer VARCHAR(100),
    IN phoneNumberCustomer VARCHAR(10),
    IN addressCustomer VARCHAR(255),
    IN birthdateCustomer DATE,
    IN cardNumberCustomer VARCHAR(30),
    IN bankNameCustomer VARCHAR(100)
)
BEGIN
	DECLARE getId INT;
    IF NOT EXISTS (SELECT * FROM ACCOUNT WHERE username = usernameCustomer) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Customer does not have an username';
    ELSEIF emailCustomer NOT REGEXP '^[a-zA-Z0-9][+a-zA-Z0-9._-]*@[a-zA-Z0-9][a-zA-Z0-9]*\\.[a-zA-Z]{2,4}$' THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid Email address';
    ELSEIF LENGTH(phoneNumberCustomer) <> 10 OR phoneNumberCustomer NOT REGEXP '^0[0-9]{9}$' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid phone number (must have 10 number digits)';
    ELSE
        SET getId = (SELECT ID FROM ACCOUNT WHERE username = usernameCustomer);
        INSERT INTO CUSTOMER (
             ID, name, email, phone_number, address, birthdate , card_number, bank_name
        ) VALUES (
            getID, nameCustomer, emailCustomer, phoneNumberCustomer, addressCustomer, birthdateCustomer, cardNumberCustomer, bankNameCustomer
        );
    END IF;
END$$

DELIMITER ;


DELIMITER $$
CREATE PROCEDURE DeleteUserAccount (IN inputname VARCHAR(100), IN inputpasswd VARCHAR(100))
BEGIN
	IF (NOT EXISTS (SELECT * FROM ACCOUNT WHERE username = inputname AND password = inputpasswd)) THEN SIGNAL SQLSTATE '45000' set message_text = 'Tên đăng nhập không tồn tại';
    ELSE
		DELETE FROM ACCOUNT WHERE username = inputname;
    END IF;
END $$

DELIMITER ;

select * from Account;

-- -----------------------------
-- FUNCTION 1: count_food
-- -----------------------------

DROP FUNCTION IF EXISTS count_food;

DELIMITER $$ 
CREATE FUNCTION count_food(
	restaurant_name VARCHAR(255),
	category_id INT 
)
RETURNS INT
DETERMINISTIC
BEGIN 
	DECLARE count INT;
	DECLARE restaurant_exists INT; 

	IF category_id < 0 THEN 
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Category ID must be positive';
	END IF;

	IF restaurant_name REGEXP '^[\\p{L} ]+$' THEN
		SELECT COUNT(*) INTO restaurant_exists FROM RESTAURANT 
		WHERE name = restaurant_name;

		IF restaurant_exists = 0 THEN 
			SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Restaurant does not exist!';
		ELSE 
			SELECT COUNT(*) INTO count FROM FOOD_ITEM fi
			JOIN CATEGORY c ON fi.categoryID = c.ID 
			JOIN RESTAURANT r ON c.RID = r.ID 
			WHERE categoryID = category_id AND r.name = restaurant_name;
		END IF;
	ELSE 
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Wrong restaurant format name!';
	END IF;

	RETURN count;
END $$

DELIMITER ;

-- -----------------------------
-- FUNCTION 2: categorize_food
-- -----------------------------

DROP FUNCTION IF EXISTS categorize_food;
DELIMITER $$

CREATE FUNCTION categorize_food(
    restaurant_name VARCHAR(255),
    food_name VARCHAR(255)
)
RETURNS VARCHAR(15)
DETERMINISTIC
BEGIN
    DECLARE price_level VARCHAR(15);
    DECLARE food_item_price INT;
    DECLARE average_price INT;
    DECLARE min_price INT;
    DECLARE max_price INT;


    IF restaurant_name NOT REGEXP '^[\\p{L} ]+$' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Wrong restaurant format name!';
    END IF;
    
    IF food_name NOT REGEXP '^[\\p{L}0-9À-ÿ \-\.,\(\)]+$' THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid food name';
	END IF;

    IF (SELECT COUNT(*) 
        FROM FOOD_ITEM fi 
        JOIN CATEGORY c ON fi.categoryID = c.ID
        JOIN RESTAURANT r ON c.RID = r.ID
        WHERE fi.name = food_name AND r.name = restaurant_name) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Food item does not exist in the restaurant!';
    END IF;

    SELECT price INTO food_item_price
    FROM FOOD_ITEM fi
    JOIN CATEGORY c ON fi.categoryID = c.ID
    JOIN RESTAURANT r ON c.RID = r.ID
    WHERE fi.name = food_name AND r.name = restaurant_name;

    SELECT 
        AVG(price), MIN(price), MAX(price)
    INTO average_price, min_price, max_price
    FROM FOOD_ITEM fi
    JOIN CATEGORY c ON fi.categoryID = c.ID
    JOIN RESTAURANT r ON c.RID = r.ID
    WHERE r.name = restaurant_name;

    IF food_item_price >= (average_price + max_price) / 2 THEN
        SET price_level = 'High';
    ELSEIF food_item_price <= (average_price + min_price) / 2 THEN
        SET price_level = 'Low';
    ELSE
        SET price_level = 'Medium';
    END IF;

    RETURN price_level;
END $$

DELIMITER ;


-- =====================================================================================================================

-- -----------------------------
-- INSERT MEANINGFUL DATA 1.1.2
-- -----------------------------

-- Insert data into ACCOUNT
INSERT INTO ACCOUNT (username, password) VALUES
('hknam', 'Nam12345678'),
('taminh', 'Minh12345678'),
('cnlam', 'Lam12345678'),
('nchlong', 'Long12345678'),
('dnphu', 'Phu12345678'),
('banhmihuynhhoa', 'HuynhHoa12345678'),
('comtamPLT', 'PLT12345678'),
('bunthitnuongHang', 'bunthitnuongHang123456'),
('phoVietNam', 'phoVietNam123456'),
('pizzaCompany', 'pizzacompany123456'),

('JDoe','14564556456'),
('JSmith','456489456'),
('AliceNguyen','afafafafadfd'),

('NhahangHoangTam', '1465456456'),
('DimTuTac', '546579841'),
('SanFoulu', '8789632123'),
('BotChien', '3215648974'),
('PizzaHut', 'p56456231231');


-- Insert into CUSTOMER based on usernames for individuals
INSERT INTO CUSTOMER (ID, name, email, exchange_points, phone_number, address, birthdate, card_number, bank_name)
VALUES
(1, 'Hồ Khánh Nam', 'hknam@gmail.com', 100, '0913133811', '123 Đường Nam Kỳ Khởi Nghĩa, Q.1, TP.HCM', '2004-08-15', '1111222233334444', 'Vietcombank'),
(2, 'Trịnh Anh Minh', 'taminh@yahoo.com', 60, '0922222222', '456 Đường Cách Mạng Tháng 8, Q.3, TP.HCM', '2004-11-05', '5555666677778888', 'none'),
(3, 'Cao Ngọc Lâm', 'cnlam@hotmail.com', 80, '0933764233', '789 Đường Lê Văn Sỹ, Q.3, TP.HCM', '2004-05-20', '9999000011112222', 'Agribank'),
(4, 'Nguyễn Châu Hoàng Long', 'nchlong@gmail.com', 0, '0944568144', '321 Đường Nguyễn Thị Minh Khai, Q.1, TP.HCM', '2004-07-12', '3333444455556666', 'BIDV'),
(5, 'Đặng Ngọc Phú', 'dnphu@outlook.com', 200, '0955442555', '654 Đường Hai Bà Trưng, Q.1, TP.HCM', '2004-03-25', '7777888899990000', 'none'),

(11, 'John Doe', 'john@example.com', 100,'0913133691', '69 Le Loi, Q.1, TP.HCM', '1990-01-01', '3123123123213213', 'BIDV'), -- Test procedure 1
(12, 'Jane Smith', 'jane@example.com',  60, '0995133811', '456 Nguyen Canh Chan, Q.1, TP.HCM', '1992-06-15', '321321312321321', 'TMCP'), -- Test procedure 1
(13, 'Alice Nguyen', 'alice@example.com', 80, '0913133631', '12 Nguyen Thuong Hien, Q.10, TP.HCM', '1988-03-22', '32232352546452324', 'ACB'); -- Test procedure 1


-- Insert into RESTAURANT based on usernames for businesses
INSERT INTO RESTAURANT (ID, name, phone_number, address, open_hour, close_hour)
VALUES
(6, 'Bánh Mì Huynh Hoa', '0966666666', '26 Lê Thị Riêng, Q.1, TP.HCM', '06:00:00', '22:00:00'),
(7, 'Cơm Tấm Phúc Lộc Thọ', '0977777777', '345 Nguyễn Trãi, Q.5, TP.HCM', '08:00:00', '22:00:00'),
(8, 'Bún Thịt Nướng Hằng', '0988888888', '12 Nguyễn Thị Nghĩa, Q.1, TP.HCM', '08:00:00', '20:00:00'),
(9, 'Phở Việt Nam', '0999999999', '56 Cao Thắng, Q.3, TP.HCM', '06:30:00', '17:00:00'),
(10, 'Pizza Company', '1900633606', '207-209 Bàu Cát, Phường 13, Tân Bình, Hồ Chí Minh', '08:00:00', '22:00:00'),

(14, 'NhahangHoangTam', '0966666667', '26 Lý Thường Kiệt, Q.10, TP.HCM', '06:00:00', '22:00:00'),
(15, 'DimTuTac', '0977777778', '345 Trần Hưng Đạo, Q.5, TP.HCM', '08:00:00', '22:00:00'),
(16, 'SanFoulu', '0988888889', '12 Huyền Trân Công Chúa, Q.1, TP.HCM', '08:00:00', '20:00:00'),
(17, 'BotChien', '0999999991', '56 Lý Chính Thắng, Q.3, TP.HCM', '06:30:00', '17:00:00'),
(18, 'PizzaHut', '1900633604', '207-209 Bà Huyện Thanh Quan, Q.3, Hồ Chí Minh', '08:00:00', '22:00:00');


INSERT INTO DISCOUNT_FROM_RESTAURANT (code, usageLimit, used_Count, start_date, end_date, value, RID)
VALUES
('DIS_HH5', 100, 0, '2024-12-01', '2024-12-08', 5000, 6),
('DIS_PLT10', 10, 0, '2024-12-01', '2024-12-08', 10000, 7),
('DIS_BTN20', 30, 0, '2024-12-01', '2024-12-08', 20000, 8),
('DIS_PVN10', 20, 0, '2024-12-01', '2024-12-08', 10000, 9),
('DIS_SPECIAL', 20, 0, '2024-12-01', '2024-12-08', 20000, 6),


('DIS_HT5', 100, 0, '2024-12-01', '2024-12-08', 5000, 14),
('DIS_DIMTUTAC10', 50, 0, '2024-12-01', '2024-12-08', 10000, 15),
('DIS_SanFoulu20', 30, 0, '2024-12-01', '2024-12-08', 20000, 16),
('DIS_BotChien10', 20, 0, '2024-12-01', '2024-12-08', 10000, 17),
('DIS_SPECIAL2', 20, 0, '2024-12-01', '2024-12-08', 20000, 18),

('DIS_COMPANY1', 20, 0, '2024-11-30', '2024-12-07', 20000, 10);


INSERT INTO DISCOUNT_FROM_EXCHANGE_POINT (code, exchange_date,  end_date, value, CID)
VALUES
('EXC_NAM20', '2024-12-01 00:00:00', '2024-12-08 23:59:59', 5000, 1),
('EXC_MINH80', '2024-12-01 00:00:00', '2024-12-08 23:59:59', 30000, 2),
('EXC_LAM40', '2024-12-01 00:00:00', '2024-12-08 23:59:59', 15000, 3),
('EXC_PHU120', '2024-12-01 00:00:00', '2024-12-08 23:59:59', 50000, 5),

('EXC_DOE20', '2024-12-01 00:00:00', '2024-12-08 23:59:59', 5000, 11),
('EXC_SMITH80', '2024-12-01 00:00:00', '2024-12-08 23:59:59', 30000, 12),
('EXC_ALICE40', '2024-12-01 00:00:00', '2024-12-08 23:59:59', 15000, 13);


INSERT INTO CATEGORY (name, RID)
VALUES
('Bánh Mì', 6),
('Cơm', 7),
('Bún', 8),
('Phở', 9),
('Nước uống', 6),
('Nước uống', 7),
('Nước uống', 8),
('Nước uống', 9),
('pizza', 10), -- test trigger 2
('mì', 10), -- test trigger 2
('Bánh', 14),
('Mì', 15),
('Dimsum', 16),
('Đồ Chiên', 17),

('Pizza', 18),
('Gà', 18),
('Mì', 18),
('Salad', 18),
('Khoai tây chiên', 18),
('Nước uống', 18),

('Bánh', 6),
('Bơ', 6),
('Chà bông', 6),
('Cơm', 6),
('Chả lụa', 6),
('Pate', 6),
('Dăm bông', 6);



-- Insert data into FOOD_ITEM
INSERT INTO FOOD_ITEM (name, price, image, categoryID)
VALUES
('Bánh Mì Thập Cẩm', 68000, 'https://phapluatbanquyen.phaply.vn/uploads/images/users/images/2021/12/5515151565656.png', 1),
('Bánh Mì Ốp La', 30000, 'https://img-global.cpcdn.com/recipes/01914f4be6cc4786/1200x630cq70/photo.jpg', 1),
('Bánh Mì Phá Lấu', 40000, 'https://media-cdn-v2.laodong.vn/storage/newsportal/2023/12/17/1281247/Banh-Mi-3.jpg', 1),
('Cơm mực dồn thịt', 90000, 'https://comtamthuankieu.com.vn/wp-content/uploads/2020/12/IMG_0100-scaled.jpg', 2),
('Cơm Tấm Sườn', 60000, 'https://comtamthuankieu.com.vn/wp-content/uploads/2020/12/xhdt.png', 2),
('Cơm bì chả', 45000, 'https://cdn.tgdd.vn/2020/08/CookProduct/52-1200x676.jpg', 2),
('Cơm ba rọi nướng', 60000, 'https://thenguyen.vn/files/products/product_1071/com-ba-roi-nuong.jpg', 2),
('Cơm sườn cọng nướng', 80000, 'https://comtamthuankieu.com.vn/wp-content/uploads/2020/12/IMG_0054-scaled.jpg', 2),

('Bún Thịt Nướng Đặc Biệt', 40000, 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTL5eeW1rOAoRefLYGQenWho1QyBzfPK9jHNA&s', 3),
('Phở Tái', 45000, 'https://bizweb.dktcdn.net/thumb/grande/100/479/802/products/z5194000249948-d9ce50b9cd9dba2091e04aa86562b9ab.jpg?v=1708931870103', 4),
('Coca', 20000, 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQEeRLdAYYXX89qnF7bBe3mQkN0EBgp8U5VuA&s', 7),
('Trà đá', 10000, 'https://image.tienphong.vn/w890/Uploaded/2024/rkznae/2020_06_11/uong_tra_da_moi_ngay_nhung_khong_phai_ai_cung_biet_nhung_cam_ki_nay_04_6503_UJUV.jpg', 8),

('Pizza hải sản pesto', 169000, 'http://thepizzacompany.vn/images/thumbs/000/0002624_seafood-pesto_300.png', 9), -- test trigger 2 1.1.1
('Mỳ Ý sốt kem cà chua', 139000, 'http://thepizzacompany.vn/images/thumbs/000/0002257_spaghetti-shrimp-rose_300.png', 10), -- test trigger 2 1.1.1

('Bánh xèo', 69000, 'https://www.huongnghiepaau.com/wp-content/uploads/2017/02/cach-lam-banh-xeo-mien-trung.jpg', 11),
('Mì xào vịt', 350000, 'https://vit29.com/media/news/1502_mtrnvtquay.jpg', 12),
('Há cảo', 40000, 'https://tiki.vn/blog/wp-content/uploads/2023/09/ha-cao-4.jpg', 13),
('Bột chiên trứng ', 30000, 'https://i.ytimg.com/vi/q7is9fGsGuw/maxresdefault.jpg', 14),

('Pizza pepperoni', 200000, 'https://file.hstatic.net/1000389344/article/pepperoni_5_1c9ba759196f480eba397d628ac958ed_1024x1024.jpg', 15),
('Cánh gà giòn Xốt Cay (4 miếng)', 79000, 'https://cdn.pizzahut.vn/images/Web_V3/Products_MenuTool/Ga-Mala%204_20241122160004425.jpeg', 16),
('Mì Ý bò Bằm Xốt Cà Chua', 120000, 'https://cdn.pizzahut.vn/images/Web_V3/Products_MenuTool/Mi_Y_Thit_Bam_Xot_Ca_Chua_400x275.jpg', 17),
('Xà Lách Da Cá Hồi', 89000, 'https://cdn.pizzahut.vn/images/Web_V3/Products_MenuTool/Xa_Lach_Da_Ca_Hoi_400x275.jpg', 15),
('Pizza Hải Sản Nhiệt Đới', 229000, 'https://cdn.pizzahut.vn/images/Web_V3/Products_MenuTool/Pizza_Hai_San_Nhiet_Doi_400x275.jpg', 15),
('Pizza Thập Cẩm', 229000, 'https://cdn.pizzahut.vn/images/Web_V3/Products_MenuTool/Pizza_Thap_Cam_400x275.jpg', 15),
('Pizza Cơn lốc Hải Sản', 239000, 'https://cdn.pizzahut.vn/images/Web_V3/Products_MenuTool/Pizza_Con_Loc_Hai_San_400x275.jpg', 15),
('Khoai Tây Chiên', 59000, 'https://cdn.pizzahut.vn/images/Web_V3/Products_MenuTool/Khoai_Tay_Chien_400x275.jpg', 19),
('Pepsi không calo 320ml', 30000, 'https://cdn.pizzahut.vn/images/Web_V3/Products_MenuTool/Pepsi_NoCalo_Can_400x275.jpg', 20),
('Pepsi Lemon 320ml', 30000, 'https://cdn.pizzahut.vn/images/Web_V3/Products_MenuTool/Pepsi_Lemon_Can_400x275.jpg', 20),

('Bánh bao đặc biệt', 35000, 'https://banhmihuynhhoa.vn/wp-content/uploads/2024/10/dscf0910-min-309dc785-f3b9-4047-8912-bf0ad14c01c7-300x300.jpg', 1),
('Bơ tươi Huynh Hoa', 65000, 'https://cdn.pizzahut.vn/images/Web_V3/Products_MenuTool/Pepsi_Lemon_Can_400x275.jpg', 1),
('Chả đặc biệt', 120000, 'https://banhmihuynhhoa.vn/wp-content/uploads/2024/10/dscf1089-min-300x300.jpg', 1),
('Cơm cháy siêu cay', 50000, 'https://banhmihuynhhoa.vn/wp-content/uploads/2024/10/dscf1089-min-300x300.jpg', 1),
('Chả lụa đặc biệt', 140000, 'https://banhmihuynhhoa.vn/wp-content/uploads/2024/10/DSCF1265-300x300.jpg', 1),
('Pate Huynh Hoa', 90000, 'https://banhmihuynhhoa.vn/wp-content/uploads/2024/10/FOOD-HUYNH-HOA25835-600x600.jpg', 1),
('Dăm bông vai vuông', 140000, 'https://banhmihuynhhoa.vn/wp-content/uploads/2024/10/FOOD-HUYNH-HOA25889-600x600.jpg', 1),


('Pizza Tôm Cocktail', 159000, 'http://thepizzacompany.vn/images/thumbs/000/0002216_shrimp-ctl-test_300.png', 9),
('Pizza Hải Sản Nhiệt Đới', 159000, 'http://thepizzacompany.vn/images/thumbs/000/0002216_shrimp-ctl-test_300.png', 9),
('Pizza Aloha', 149000, 'http://thepizzacompany.vn/images/thumbs/000/0002216_shrimp-ctl-test_300.png', 9),
('Pizza Thịt Xông Khói', 149000, 'http://thepizzacompany.vn/images/thumbs/000/0002221_bacon-sup_300.png', 9),
('Pizza Hải Sản Cao Cấp', 149000, 'http://thepizzacompany.vn/images/thumbs/000/0002214_sf-deluxe_300.png', 9),
('Mì Ý Chay Sốt Marinara', 109000, 'http://thepizzacompany.vn/images/thumbs/000/0003135_spaghetti-vegetarian-w-marinara-sauce_300.png', 10);







-- Insert data into FOOD_DELIVER
INSERT INTO FOOD_DELIVER (phone_number, vehicle_number, name)
VALUES
('0911223344', '59A-12345', 'Nguyễn Văn Tài'),
('0922334455', '59B-67890', 'Nguyễn Minh Mẫn'),
('0921134425', '59B-66490', 'Hồ Minh Huy'),
('0331134625', '60B-66490', 'Lê Tuấn Anh'),
('0335534345', '60B-66992', 'Hà Minh Giang');


INSERT INTO FOOD_ORDER (Payment_method, address, order_status, order_time_stamp, review, rating, ship_status, get_status, delivery_fee, CID, RID, FDID)
VALUES
('CARD', '123 Đường Nam Kỳ Khởi Nghĩa, Q.1, TP.HCM','delivered', '2024-12-01 14:30:00', 'Dịch vụ rất tốt!', 5, 'delivered', 'finished', 15000, 1, 6, 1),
('CASH', '456 Đường Cách Mạng Tháng 8, Q.3, TP.HCM', 'delivered', '2024-12-01 14:30:00', 'Dịch vụ tệ!', 1, 'delivered', 'finished', 15000, 2, 7, 2),
('CASH', '789 Đường Lê Văn Sỹ, Q.3, TP.HCM','pending', '2024-12-01 14:30:00', '', 5, null, null, 15000, 3, 6, 1), -- default 5 star even customer doesnot receive food yet
('CARD', '123 Đường Nam Kỳ Khởi Nghĩa, Q.1, TP.HCM', 'pending', '2024-12-01 14:30:00', '', 5, null, null, 15000, 1, 10, 3), -- test trigger 2

('CARD', '69 Le Loi, Q.1, TP.HCM', 'delivered', '2024-02-13 15:31:00', 'Dịch vụ hoàn hảo!', 5, 'delivered', 'finished', 25000, 11, 6, 4),
('CASH', '456 Nguyen Canh Chan, Q.1, TP.HCM', 'delivered', '2024-09-01 10:30:00', 'Dịch vụ không tốt !', 3, 'delivered', 'finished', 20000, 12, 15, 5),
('CASH', '12 Nguyen Thuong Hien, Q.10, TP.HCM', 'pending', '2024-08-24 16:20:00', 'Dịch vụ oke', 5, 'delivered', 'finished', 10000, 13, 16, 5), 
-- ORDER WITH MANY DISCOUNT USED (PROCEDURE 1 1.2.3)
-- Delivered Orders
('CARD', '654 Đường Hai Bà Trưng, Q.1, TP.HCM', 'delivered', '2024-12-02 18:45:00', 'Hương vị tuyệt vời!', 5, 'delivered', 'finished', 20000, 5, 6, 1),
('CASH', '321 Đường Nguyễn Thị Minh Khai, Q.1, TP.HCM', 'delivered', '2024-12-02 19:00:00', 'Nhân viên giao hàng thân thiện.', 4, 'delivered', 'finished', 15000, 4, 7, 2),
('CARD', '207-209 Bàu Cát, Phường 13, Tân Bình, TP.HCM', 'delivered', '2024-12-03 12:30:00', 'Pizza ngon!', 5, 'delivered', 'finished', 20000, 1, 10, 3),
('CASH', '12 Nguyễn Thị Nghĩa, Q.1, TP.HCM', 'delivered', '2024-12-03 13:15:00', 'Bún thịt nướng siêu ngon!', 5, 'delivered', 'finished', 15000, 3, 8, 4),
('CARD', '56 Cao Thắng, Q.3, TP.HCM', 'delivered', '2024-12-04 17:00:00', 'Phở hơi mặn.', 3, 'delivered', 'finished', 10000, 11, 9, 1),

-- Pending Orders
('CARD', '345 Nguyễn Trãi, Q.5, TP.HCM', 'pending', '2024-12-04 14:30:00', '', 5, NULL, NULL, 15000, 2, 7, 2),
('CASH', '26 Lê Thị Riêng, Q.1, TP.HCM', 'pending', '2024-12-04 16:00:00', '', 5, NULL, NULL, 15000, 12, 6, 3),
('CARD', '56 Lý Chính Thắng, Q.3, TP.HCM', 'pending', '2024-12-04 18:45:00', '', 5, NULL, NULL, 10000, 13, 17, 4),
('CASH', '789 Đường Lê Văn Sỹ, Q.3, TP.HCM', 'confirmed', '2024-12-01 20:15:00', '', 5, 'delivering', 'in_process', 15000, 4, 7, 1),
('CARD', '207-209 Bà Huyện Thanh Quan, Q.3, TP.HCM', 'confirmed', '2024-12-02 22:00:00', '', 5, 'delivering', 'in_process', 15000, 11, 6, 5),

-- Phu order
('CARD', '654 Đường Hai Bà Trưng, Q.1, TP.HCM', 'confirmed', '2024-12-02 21:00:00', '', 5, 'delivering', 'in_process', 15000, 5, 6, 5),
('CARD', '654 Đường Hai Bà Trưng, Q.1, TP.HCM', 'confirmed', '2024-12-02 19:00:00', '', 5, 'delivering', 'in_process', 15000, 5, 7, 2),
('CARD', '654 Đường Hai Bà Trưng, Q.1, TP.HCM', 'confirmed', '2024-12-02 16:00:00', '', 5, 'delivering', 'in_process', 15000, 5, 8, 1),
-- customer 12
('CARD', '456 Nguyen Canh Chan, Q.1, TP.HCM', 'confirmed', '2024-12-02 16:00:00', '', 5, 'delivering', 'in_process', 15000, 12, 6, 3),
('CARD', '456 Nguyen Canh Chan, Q.1, TP.HCM', 'confirmed', '2024-12-02 17:00:00', '', 5, 'delivering', 'in_process', 14000, 12, 7, 4),
('CARD', '456 Nguyen Canh Chan, Q.1, TP.HCM', 'confirmed', '2024-12-02 18:30:00', '', 5, 'delivering', 'in_process', 15000, 12, 8, 5),
-- customer 13
('CASH', '12 Nguyen Thuong Hien, Q.10, TP.HCM', 'confirmed', '2024-12-02 08:15:00', '', 5, 'delivering', 'in_process', 15000, 13, 10, 1),
('CASH', '12 Nguyen Thuong Hien, Q.10, TP.HCM', 'confirmed', '2024-12-02 09:00:00', '', 5, 'delivering', 'in_process', 13000, 13, 18, 2),
('CASH', '12 Nguyen Thuong Hien, Q.10, TP.HCM', 'confirmed', '2024-12-02 20:00:00', '', 5, 'delivering', 'in_process', 13000, 13, 6, 2),
-- CUSTOMER 1
('CASH', '123 Đường Nam Kỳ Khởi Nghĩa, Q.1, TP.HCM', 'delivered', '2024-12-02 08:15:00', '', 5, 'delivered', 'finished', 15000, 1, 6, 3),
('CASH', '123 Đường Nam Kỳ Khởi Nghĩa, Q.1, TP.HCM', 'delivered', '2024-12-02 09:00:00', '', 5, 'delivered', 'finished', 15000, 1, 7, 4),
('CASH', '123 Đường Nam Kỳ Khởi Nghĩa, Q.1, TP.HCM', 'delivered', '2024-12-02 20:00:00', '', 5, 'delivered', 'finished', 25000, 1, 8, 5),
-- CUSTOMER 2
('CARD', '456 Đường Cách Mạng Tháng 8, Q.3, TP.HCM', 'confirmed', '2024-12-02 16:00:00', '', 5, 'delivering', 'in_process', 15000, 2, 6, 3),
('CARD', '456 Đường Cách Mạng Tháng 8, Q.3, TP.HCM', 'confirmed', '2024-12-02 17:00:00', '', 5, 'delivering', 'in_process', 15000, 2, 7, 1),
('CARD', '456 Đường Cách Mạng Tháng 8, Q.3, TP.HCM', 'confirmed', '2024-12-02 18:30:00', '', 5, 'delivering', 'in_process', 15000, 2, 8, 1),
-- CUSTOMER 3
('CASH', '789 Đường Lê Văn Sỹ, Q.3, TP.HCM', 'confirmed', '2024-12-02 08:15:00', '', 5, 'delivering', 'in_process', 15000, 3, 10, 1),
('CASH', '789 Đường Lê Văn Sỹ, Q.3, TP.HCM', 'confirmed', '2024-12-02 09:00:00', '', 5, 'delivering', 'in_process', 17000, 3, 18, 2),
('CASH', '789 Đường Lê Văn Sỹ, Q.3, TP.HCM', 'confirmed', '2024-12-02 20:00:00', '', 5, 'delivering', 'in_process', 15000, 3, 6, 3),
-- CUSTOMER 4
('CASH', '207-209 Bàu Cát, Phường 13, Tân Bình, TP.HCM', 'confirmed', '2024-12-02 08:15:00', '', 5, 'delivering', 'in_process', 14000, 4, 10, 1),
('CASH', '207-209 Bàu Cát, Phường 13, Tân Bình, TP.HCM', 'confirmed', '2024-12-02 09:00:00', '', 5, 'delivering', 'in_process', 16000, 4, 18, 5),
('CASH', '207-209 Bàu Cát, Phường 13, Tân Bình, TP.HCM', 'confirmed', '2024-12-02 20:00:00', '', 5, 'delivering', 'in_process', 16000, 4, 6, 5);


-- Insert data into `use`
INSERT INTO `use` (CID, DFRcode)
VALUES
(1, 'DIS_HH5');

select * from food_order;
select * from food_item;
select * from restaurant;



-- Insert data into `contain`
INSERT INTO `contain` (FOID, FIID, quantity)
VALUES
(1, 1, 3),
(2, 4, 2),

(3,1,3),



(4, 13, 2), -- test trigger 2: 2 Pizzas
(4, 14, 1), -- test trigger 2: 1 Pasta

(5, 30, 2),
(6, 16, 2),
(7, 17, 3),

(8,1,3),
(8,2,4),
(8,3,1),

(9,4,3),
(9,6,2),
(9,5,1),

(10,36,2),
(10,37,2),
(10,38,1),
(10,39,5),

(11,9,3),
(12,10,2),


(13,8,5),
(13,7,1),

(14,1,4),
(15,18,2),

(16,8,1),
(16,7,3),


(17,1,5),

(18,1,2),
(18,2,5),


(19,4,5),
(19,5,4),



(20,9,3),


(21,32,2),
(21,33,4),
(21,34,3),


(22,8,1),

(23,9,2),


(24,14,5),

(25,22,2),

(26,29,3),
(26,30,1),

(27,1,2),
(27,2,3),

(28,5,1),
(28,6,1),

(29,9,7),

(30,2,4),
(30,3,5),

(31,5,2),
(31,8,3),


(32,9,2),
(33,13,3),


(34,22,5),

(35,32,2),
(35,34,3),

(36,14,2),
(36,13,3),

(37,22,2),

(38,1,3),
(38,2,3),
(38,3,3);

select * from food_order;
select * from food_item;
select * from restaurant;




select * from restaurant;
select * from discount_from_restaurant;
select * from food_order;
-- Insert data into `apply_for`
INSERT INTO apply_for (DFRcode, FOID)
VALUES
('DIS_HH5', 1),
('DIS_HH5', 3),
('DIS_HH5', 5),
('DIS_HH5', 14),
('DIS_PLT10', 2),
('DIS_PLT10', 9),
('DIS_PLT10', 13),
('DIS_PLT10', 16),
('DIS_BTN20', 11),
('DIS_PVN10', 12),
('DIS_COMPANY1',4),
('DIS_COMPANY1',10),
('DIS_BotChien10', 15),
('DIS_SPECIAL2', 17),
('DIS_HH5', 18),
('DIS_HH5', 21),
('DIS_HH5', 26),
('DIS_HH5', 27),
('DIS_HH5', 30),
('DIS_HH5', 35),
('DIS_HH5', 38),
('DIS_PLT10', 19),
('DIS_PLT10', 22),
('DIS_PLT10', 28),
('DIS_PLT10', 31),
('DIS_BTN20', 20),
('DIS_BTN20', 23),
('DIS_BTN20', 29),
('DIS_BTN20', 32),
('DIS_COMPANY1', 24),
('DIS_COMPANY1', 33),
('DIS_COMPANY1', 36),
('DIS_SPECIAL2', 25),
('DIS_SPECIAL2', 34),
('DIS_SPECIAL2', 37);


-- Insert data into discount_point_apply_for
INSERT INTO discount_point_apply_for (DFEPcode, FOID)
VALUES
('EXC_MINH80', 2);


-- =====================================================================================================================


-- TEST IN 1.1.1

-- TRIGGER 2
-- Insert into DISCOUNT_FROM_RESTAURANT
-- INSERT INTO DISCOUNT_FROM_RESTAURANT (code, usageLimit, used_Count, start_date, end_date, value, RID)
-- VALUES ('DISC_COMPANY', 10, 0, '2024-07-01', '2024-07-08', 20000, 10);

-- Verify Food Order Price (Pizza + Pasta) IN FOOD_ORDER.ID = 4
-- SELECT SUM(FI.price * C.quantity) AS total_order_price
-- FROM CONTAIN C
-- JOIN FOOD_ITEM FI ON C.FIID = FI.ID
-- WHERE C.FOID = 4;

-- INSERT INTO APPLY_FOR (DFRcode, FOID) VALUES ('DISC_COMPANY', 4);

-- Update discount to exceed 30%
-- UPDATE DISCOUNT_FROM_RESTAURANT SET value = 500000 WHERE code = 'DISC_COMPANY';

-- INSERT TO TRIGGER THE TRIGGER 2
-- INSERT INTO APPLY_FOR (DFRcode, FOID) VALUES ('DISC_COMPANY', 4);


-- TEST IN 1.2.1
-- PROCEDURE 1
-- CALL AddFoodItem("Cơm tấm sườn bì chả", 70000, 'https://product.hstatic.net/200000523823/product/com_tam_suon_bi_cha_c50c564871254d7ea56b6d82344ae9bf_master.jpg',2);
-- ERROR (3):
-- CALL AddFoodItem("Cơm tấm sườn bì chả", 0, 'https://product.hstatic.net/200000523823/product/com_tam_suon_bi_cha_c50c564871254d7ea56b6d82344ae9bf_master.jpg',2);
-- CALL AddFoodItem("", 30000, "", 3); 
-- CALL AddFoodItem("Bún bò huế", 30000, "", 30);

-- PROCEDURE 2
-- CALL DeleteFoodItem(100); --ERROR
-- CALL DELETEFOODITEM(7);

-- PROCEDURE 3
-- CALL UpdateFoodItem(1, 'Bánh Mì Đầy đủ', 70000, 'https://nghenghiepcuocsong.vn/wp-content/uploads/2023/01/z4025571501634_d4354c69e24aa7d1ee884433db8b4763.jpg', 6);


-- TEST TRIGGER 1 IN 1.2.2
-- INSERT INTO FOOD_ORDER (Payment_method, address, order_status, order_time_stamp, review, rating, ship_status, get_status, delivery_fee, CID, RID, FDID)
-- VALUES
-- ('CASH', '123 Bà Huyện Thanh Quan, Q.3, TP.HCM', 'confirmed', '2024-12-01 14:30:00', 'Dịch vụ tệ!', 1, 'delivered', 'finished', 15000, 3, 8, 2),
-- ('CASH', '123 Bà Huyện Thanh Quan, Q.3, TP.HCM', 'confirmed', '2024-12-01 14:30:00', 'Dịch vụ tệ!', 1, 'delivered', 'finished', 15000, 4, 9, 2);

-- select * from customer;

-- UPDATE FOOD_ORDER
-- SET order_status = 'delivered'
-- WHERE ID IN (3,4);

-- TEST TRIGGER 2 IN 1.2.2
-- SELECT * FROM CONTAIN;
-- SELECT * FROM FOOD_ORDER;
-- UPDATE CONTAIN
-- SET QUANTITY = 2
-- WHERE FOID = 1 AND FIID = 1;





-- TEST ADDITIONAL PROCEDURE

-- TEST
-- call AddUserAccount('hknam', 'Nam12345678');
-- call AddUserAccount('taminh', 'Minh12345678');
-- call AddUserAccount('cnlam', 'Lam12345678');
-- call AddUserAccount('nchlong', 'Long12345678');
-- call AddUserAccount('dnphu', 'Phu12345678');

-- select * from account;
-- select * from customer;
-- call AddCustomer('hknam', 'Hồ Khánh Nam', 'hknam@gmail.com', '0913133811', '123 Đường Nam Kỳ Khởi Nghĩa, Q.1, TP.HCM', '2004-08-15', '1111222233334444', 'Vietcombank');
-- call AddCustomer('nchlong', 'Nguyễn Châu Hoàng Long', 'nchlong@gmail.com', '0944568144', '321 Đường Nguyễn Thị Minh Khai, Q.1, TP.HCM', '2004-07-12', '3333444455556666', 'BIDV');
-- CALL AddUserAccount('admin', '123456789');

-- call DeleteUserAccount('admin', '123456789');


-- ------------------------*********************----------------------------------------------------------

-- TEST PROCEDURE 1 CỦA PHẦN  1.2.3

-- CALL RetrieveOrdersByCustomerWithDiscounts(1);

-- ------------------------**************************------------------------------------------------------------
-- TEST PROCEDURE 2 CHO PHẦN 1.2.3 

-- CALL UpdateDiscountUsageAndCheckLimit(2);
-- SELECT * FROM DISCOUNT_FROM_RESTAURANT;
--  SELECT * FROM apply_for;

-- insert into apply_for(DFRcode,FOID) 
-- values
-- ('DIS_SPECIAL',5), 
-- ('DIS_SPECIAL', 1);


 -- insert into apply_for(DFRcode,FOID) 
 -- values
 -- ('DIS_PLT10',2);


-- ------------------------**************************------------------------------------------------------------
-- TEST FUNCTION 1 CHO PHẦN 1.2.4

-- SELECT count_food('PizzaHut', 15) as result_1.2.4.1

-- TEST FUNCTION 2 CHO PHẦN 1.2.4

-- SELECT categorize_food('PizzaHut', 'Pepsi Lemon 320ml') as result_1.2.4.2


-- SET SQL_SAFE_UPDATES = 1;