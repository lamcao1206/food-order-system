import express from "express";
import FoodItemController from "../controllers/task1.controller.js";

const router = express.Router();

router.get("/", FoodItemController.prototype.getFoodItem);
router.delete("/deleteone/:ID", FoodItemController.prototype.deleteFoodItem);
router.post("/addone", FoodItemController.prototype.addFoodItem);
router.put("/updateone/:ID", FoodItemController.prototype.updateFoodItem);
router.get("/res-category",FoodItemController.prototype.getRestaurant_Category);

export default router;
