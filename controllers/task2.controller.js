import pool from "../configs/db.config.js";

export default class Task2 {
  async getdata (req,res,next) {
    try {
      const {ID}=req.params;
      const [result] = await pool.execute('CALL UpdateDiscountUsageAndCheckLimit(?)',[ID]);
      console.log(result);
      res.status(200).json({
        status:"success",
        result
      })
    } catch(err) {
      console.log(err.message);
    }
  }
}