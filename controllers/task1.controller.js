import pool from "../configs/db.config.js";


export default class FoodItemController {
  async getFoodItem(req, res) {
    try {
      const sql = `
      SELECT r.name as rname, c.name as cname, fi.name as name, fi.price as price, fi.ID as ID
      FROM food_item fi
      JOIN category c ON fi.categoryID=c.ID
      JOIN restaurant r ON c.RID=r.ID
      `;
      const [result] = await pool.execute(sql);
      res.status(200).render('fooditem.ejs',{
        status: "success",
        result,
      });
    } catch (error) {
      res.status(500).json({
        status: "error",
        message: error.message,
      });
    }
  }

  async addFoodItem(req, res) {
    try {
      const { name, price, restaurant, category } = req.body;

      //Retrieve categoryID
      const categoryRows = await find_categoryID(restaurant, category);
      if (categoryRows.length === 0) {
        return res.status(404).json({
          status: "error",
          message: "Category not found.",
        });
      }
      const categoryID = categoryRows[0].ID;

      //Check if duplicate FoodItem
      const sql_findduplicatefooditem = `
      SELECT * FROM food_item 
      WHERE name=? AND price=? AND categoryID=?
      `;

      const [rows] = await pool.execute(sql_findduplicatefooditem, [
        name,
        price,
        categoryID,
      ]);
      if (rows.length > 0) {
        return res.status(401).json({
          status: "error",
          message: "Already add this food item",
        });
      }

      //Insert new FoodItem
      const [result] = await pool.execute('CALL AddFoodItem(?,?,?,?)', [
        name,
        price,
        "",
        categoryID,
      ]);

      res.status(200).json({
        status: "success",
        message: "Fooditem created successfully!",
        result,
      });
    } catch (error) {
      res.status(500).json({
        status: "error",
        message: error.message,
      });
    }
  }

  async updateFoodItem(req, res) {
    try {
      const { ID } = req.params;
      const { name, price, restaurant, category } = req.body;

      //Retrieve categoryID
      const categoryRows = await find_categoryID(restaurant, category);
      if (categoryRows.length === 0) {
        return res.status(404).json({
          status: "error",
          message: "Category not found.",
        });
      }
      const categoryID = categoryRows[0].ID;
      
      //Update food item info
      const [result] = await pool.execute('CALL UpdateFoodItem(?,?,?,?,?)', [ID,name, price,"", categoryID]);
      res.status(200).json({
        status:"success",
        message: "User updated successfully!",
        result
      });
    } catch (error) {
      res.status(500).json({
        status: "error",
        message: error.message,
      });
    }
  }
  async deleteFoodItem(req, res) {
    try {
      const { ID } = req.params;
      // Check food item existence
      const foodItemRows = await check_fooditem_existence(ID);
      if (foodItemRows === 0) {
        return res.status(404).json({
          status: "error",
          message: "Food item not found",
        });
      }

      //Delete food item
      await pool.execute('CALL DeleteFoodItem(?)', [ID]);

      res.status(200).json({
        status: "success",
        message: "Deleted food item successfully",
      });
    } catch (error) {
      res.status(500).json({
        status: "error",
        message: error.message,
      });
    }
  }

  async getRestaurant_Category (req,res) {
    try {
      const sql =  `
    SELECT 
      c.name as categoryname,
      r.name as restaurantname
    FROM category c
    LEFT JOIN restaurant r on c.RID = r.ID
    `
    const [result]= await pool.execute(sql);
    let res_table = {}
    result.forEach(item=> {
      if (!res_table[item.restaurantname]) {
        res_table[item.restaurantname] = [];
      }
      res_table[item.restaurantname].push(item.categoryname);
    });
    return res.status(200).json({
      status:"success",
      res_table
    })
    } catch(error) {
      res.status(500).json({
        status: "error",
        message: error.message,
      });
    }
  }
}

//Retrieve categoryID from category table
const find_categoryID = async (restaurant, category) => {
  const sql_findcategory = `
      SELECT c.ID 
      FROM category c 
      JOIN restaurant r ON c.RID = r.ID 
      WHERE r.name = ? AND c.name = ?`;

  const [categoryRows] = await pool.execute(sql_findcategory, [
    restaurant,
    category,
  ]);
  return categoryRows;
};

//Validate fooditem existence
const check_fooditem_existence = async (ID) => {
  const sql_findFoodItem = "SELECT * FROM food_item WHERE ID = ?";
  const [foodItemRows] = await pool.execute(sql_findFoodItem, [ID]);
  return foodItemRows.length;
};