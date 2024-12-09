import pool from "../configs/db.config.js";

export default class Task2 {
  async getorderswithdiscount(req, res, next) {
    try {
      const { ID } = req.params;
      const [[result]] = await pool.execute(
        "CALL RetrieveOrdersByCustomerWithDiscounts(?)",
        [ID]
      );
      const sql = "SELECT * from CUSTOMER";
      const [customer] = await pool.execute(sql);
      const exist_cus = customer.filter((cus) => cus.ID === ID);
      if (result.length === 0 && exist_cus.length === 0) {
        return res.status(404).json({
          status: "error",
          message: "Customer not found",
        });
      }
      res.status(200).json({
        status: "success",
        result,
      });
    } catch (err) {
      res.status(500).json({
        status: "error",
        message: err.message,
      });
    }
  }

  async getordersbycategory(req, res, next) {
    try {
      const { ID } = req.params;
      console.log(ID);
      const [[result]] = await pool.execute(
        "CALL RetrieveOrdersByCategory(?)",
        [ID]
      );
      const sql = "SELECT * from category";
      const [category] = await pool.execute(sql);
      const exist_category = category.filter((cate) => cate.ID == ID);
      if (exist_category.length === 0) {
        return res.status(404).json({
          status: "error",
          message: "Category not found",
        });
      }

      res.status(200).json({
        status: "success",
        result,
      });
    } catch (err) {
      res.status(500).json({
        status: "error",
        message: err.message,
      });
    }
  }

  async getcustomerID(req, res, next) {
    try {
      const sql = "SELECT * from CUSTOMER";
      const [result] = await pool.execute(sql);
      res.status(200).json({
        status: "success",
        result,
      });
    } catch (err) {
      res.status(500).json({
        status: "error",
        message: err.message,
      });
    }
  }

  async getcategoryID(req, res, next) {
    try {
      const sql = `
SELECT c.ID, c.name AS categoryName, r.name AS resName
FROM category c
JOIN restaurant r ON c.RID=r.ID`;
      const [result] = await pool.execute(sql);
      res.status(200).json({
        status: "success",
        result,
      });
    } catch (err) {
      res.status(500).json({
        status: "error",
        message: err.message,
      });
    }
  }
  async deleteOrderID(req, res, next) {
    try {
      const { ID } = req.params;

      const sqlDeleteOrder = `DELETE FROM food_order WHERE ID=?`;

      const sql = "SELECT * FROM food_order WHERE id = ?";
      const [result] = await pool.execute(sql, [ID]);

      if (result.length === 0) {
        return res.status(404).json({
          status: "error",
          message: "Order not found",
        });
      }
      //Delete food item
      await pool.execute(sqlDeleteOrder, [ID]);

      res.status(200).json({
        status: "success",
        message: "Deleted order successfully",
      });
    } catch (error) {
      res.status(500).json({
        status: "error",
        message: error.message,
      });
    }
  }
}
