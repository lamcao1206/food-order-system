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
    FOREIGN KEY (DFEPcode) REFERENCES DISCOUNT_FROM_EXCHANGE_POINT(code),
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
-- PROCEDURE 2
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
-- PROCEDURE 3

DELIMITER //

CREATE PROCEDURE RetrieveOrdersByCategory(
    IN p_categoryID INT
)
BEGIN
    -- Query 1: Basic details of orders for the specified category
    SELECT 
        FO.ID AS OrderID,
        FO.order_time_stamp AS OrderTime,
        CU.name AS CustomerName,
        FI.name AS FoodItemName,
        FO.order_status AS OrderStatus
    FROM FOOD_ORDER FO
    JOIN CUSTOMER CU ON FO.CID = CU.ID
    JOIN CONTAIN C ON FO.ID = C.FOID
    JOIN FOOD_ITEM FI ON C.FIID = FI.ID
    WHERE FI.categoryID = p_categoryID
    ORDER BY FO.order_time_stamp;

    -- Query 2: Aggregate details of orders for the specified category
    SELECT 
        FO.ID AS OrderID,
        SUM(C.quantity) AS TotalItems,
        SUM(C.quantity * FI.price) AS TotalRevenue
    FROM FOOD_ORDER FO
    JOIN CONTAIN C ON FO.ID = C.FOID
    JOIN FOOD_ITEM FI ON C.FIID = FI.ID
    WHERE FI.categoryID = p_categoryID
    GROUP BY FO.ID
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
('DIS_PLT10', 1, 0, '2024-12-01', '2024-12-08', 10000, 7),
('DIS_BTN20', 30, 0, '2024-12-01', '2024-12-08', 20000, 8),
('DIS_PVN10', 20, 0, '2024-12-01', '2024-12-08', 10000, 9),
('DIS_SPECIAL', 2, 0, '2024-12-01', '2024-12-08', 20000, 6),


('DIS_HT5', 100, 0, '2024-12-01', '2024-12-08', 5000, 14),
('DIS_DIMTUTAC10', 50, 0, '2024-12-01', '2024-12-08', 10000, 15),
('DIS_SanFoulu20', 30, 0, '2024-12-01', '2024-12-08', 20000, 16),
('DIS_BotChien10', 20, 0, '2024-12-01', '2024-12-08', 10000, 17),
('DIS_SPECIAL2', 2, 0, '2024-12-01', '2024-12-08', 20000, 18);


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
('Pizza', 18);



-- Insert data into FOOD_ITEM
INSERT INTO FOOD_ITEM (name, price, image, categoryID)
VALUES
('Bánh Mì Thập Cẩm', 68000, 'https://phapluatbanquyen.phaply.vn/uploads/images/users/images/2021/12/5515151565656.png', 1),
('Cơm Tấm Sườn', 35000, 'https://comtamthuankieu.com.vn/wp-content/uploads/2020/12/xhdt.png', 2),
('Bún Thịt Nướng Đặc Biệt', 40000, 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTL5eeW1rOAoRefLYGQenWho1QyBzfPK9jHNA&s', 3),
('Phở Tái', 45000, 'https://bizweb.dktcdn.net/thumb/grande/100/479/802/products/z5194000249948-d9ce50b9cd9dba2091e04aa86562b9ab.jpg?v=1708931870103', 4),
('Coca', 20000, 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQEeRLdAYYXX89qnF7bBe3mQkN0EBgp8U5VuA&s', 7),
('Trà đá', 10000, 'https://image.tienphong.vn/w890/Uploaded/2024/rkznae/2020_06_11/uong_tra_da_moi_ngay_nhung_khong_phai_ai_cung_biet_nhung_cam_ki_nay_04_6503_UJUV.jpg', 8),
('Pizza hải sản pesto', 169000, 'http://thepizzacompany.vn/images/thumbs/000/0002624_seafood-pesto_300.png', 9), -- test trigger 2
('Mỳ Ý sốt kem cà chua', 139000, 'http://thepizzacompany.vn/images/thumbs/000/0002257_spaghetti-shrimp-rose_300.png', 10), -- test trigger 2

('Bánh xèo', 69000, 'https://www.huongnghiepaau.com/wp-content/uploads/2017/02/cach-lam-banh-xeo-mien-trung.jpg', 11),
('Mì xào vịt', 350000, 'https://vit29.com/media/news/1502_mtrnvtquay.jpg', 12),
('Há cảo', 40000, 'https://tiki.vn/blog/wp-content/uploads/2023/09/ha-cao-4.jpg', 13),
('Bột chiên trứng ', 30000, 'https://i.ytimg.com/vi/q7is9fGsGuw/maxresdefault.jpg', 14),
('Pizza pepperoni', 200000, 'https://file.hstatic.net/1000389344/article/pepperoni_5_1c9ba759196f480eba397d628ac958ed_1024x1024.jpg', 15);




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
('CASH', '12 Nguyen Thuong Hien, Q.10, TP.HCM', 'pending', '2024-08-24 16:20:00', 'Dịch vụ oke', 5, 'delivered', 'finished', 10000, 13, 16, 5); 



select * from restaurant;
select * from food_item;
select * from category;

-- Insert data into `use`
INSERT INTO `use` (CID, DFRcode)
VALUES
(1, 'DIS_HH5');

-- Insert data into `contain`
INSERT INTO `contain` (FOID, FIID, quantity)
VALUES
(1, 1, 3),
(2, 2, 2),
(4, 7, 2), -- test trigger 2: 2 Pizzas
(4, 8, 1); -- test trigger 2: 1 Pasta


-- Insert data into `apply_for`
INSERT INTO apply_for (DFRcode, FOID)
VALUES
('DIS_HH5', 1);




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






-- SET SQL_SAFE_UPDATES = 1;






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

-- 
--  Function 2 : categorize_food
-- 

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

DROP PROCEDURE IF EXISTS RetrieveOrdersByCategory;

DELIMITER //

CREATE PROCEDURE RetrieveOrdersByCategory(
    IN p_categoryID INT
)
BEGIN
    SELECT 
        FO.ID AS OrderID,
        FO.order_time_stamp AS OrderTime,
        CU.name AS CustomerName,
        FI.name AS FoodItemName,
        FI.price as FoodItemPrice,
        C.quantity as Quantity,
        FO.order_status AS OrderStatus,
        SUM(C.quantity) AS TotalItems,
        SUM(C.quantity * FI.price) AS TotalRevenue
    FROM FOOD_ORDER FO
    JOIN CUSTOMER CU ON FO.CID = CU.ID
    JOIN CONTAIN C ON FO.ID = C.FOID
    JOIN FOOD_ITEM FI ON C.FIID = FI.ID
    WHERE FI.categoryID = p_categoryID
    GROUP BY FO.ID, FO.order_time_stamp, CU.name, FI.name, FO.order_status
    HAVING TotalItems > 0
    ORDER BY TotalRevenue DESC;
END //

DELIMITER ;