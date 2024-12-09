import pool from "../configs/db.config.js";

export default class Task2  {
  async getordersswithdiscount (req,res,next) {
    try {
      const {ID}=req.params;
      const [[result]] = await pool.execute('CALL RetrieveOrdersByCustomerWithDiscounts(?)',[ID]);
      res.status(200).json({
        status:"success",
        result
      })
    } catch(err) {
      res.status(500).json({
        status: "error",
        message: err.message,
      });
    }
  }
  async getcustomerID (req,res,next) {
    try {
      const sql = 'SELECT * from CUSTOMER';
      const [result] = await pool.execute(sql);
      res.status(200).json({
        status:"success",
        result
      })
    } catch(err) {
      res.status(500).json({
        status: "error",
        message: err.message,
      });
    }
  }
  async deleteOrderID(req,res,next) {
    try {
      const { ID } = req.params;
      
      const sqlDeleteDiscount = `DELETE FROM discount_point_apply_for WHERE FOID=?`;
      const sqlDeleteOrder = `DELETE FROM food_order WHERE ID=?`;
      //Delete food item
      await pool.execute(sqlDeleteDiscount, [ID]);
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