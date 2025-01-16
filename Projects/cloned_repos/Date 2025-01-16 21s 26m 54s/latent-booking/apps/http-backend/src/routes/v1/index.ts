import { Router } from "express";
import userRouter from "./user";
import adminRouter from "./admin";
import adminEventRouter from "./admin/event";
import adminLocationRouter from "./admin/location";
import testRouter from "./test";
import bookingsRouter from "./user/bookings";
import transactionRouter from "./user/transaction"

const router: Router = Router();

router.use("/user/bookings", bookingsRouter);
router.use("/user/transaction", transactionRouter);
router.use("/user", userRouter);
router.use("/admin/event", adminEventRouter);
router.use("/admin/location", adminLocationRouter);
router.use("/admin", adminRouter);

if (process.env.NODE_ENV !== "production") {
    // Used only for testing, should never be deployed to prod.
    // Lets the tester create admins etc
    router.use("/test", testRouter);
}

export default router;