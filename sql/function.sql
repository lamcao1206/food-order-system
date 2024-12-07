-- Date: 2021/05/06

-- 
--  Function 1 : count_food
-- 

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


SELECT * FROM FOOD_ITEM fi
JOIN CATEGORY c on c.ID = fi.categoryID
JOIN RESTAURANT r on r.ID = c.RID;

-- 
--  Function 1 : categorize_food
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