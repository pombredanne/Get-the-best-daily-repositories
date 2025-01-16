
import { Router } from "express";
import { client } from "@repo/db/client"; 
import jwt from "jsonwebtoken";
import { JWT_PASSWORD } from "../../../config";
import { sendMessage } from "../../../utils/twilio";
import { getToken, verifyToken } from "../../../utils/totp";

const router: Router = Router();

router.post("/signup", async (req, res) => {
    const number = req.body.number;
    const totp = getToken(number, "AUTH");

    const user = await client.user.upsert({
        where: {
            number
        },
        create: {
            number,
            name: ""
        },
        update: {

        }
    })

    if (process.env.NODE_ENV === "production") {
        // send otp to user
        try {
            await sendMessage(`Your otp for logging into latent is ${totp}`, number)
        } catch(e) {
            res.status(500).json({
                message: "Could not send otp"
            })
            return   
        }
    }

    res.json({
        id: user.id
    })
});

router.post("/signup/verify", async (req, res) => {
    const number = req.body.number;
    const name = req.body.name;
    const otp = req.body.totp;

    if (process.env.NODE_ENV === "production" && !verifyToken(number, "AUTH", otp)) {
        res.json({
            message: "Invalid token"
        })
        return
    }

    const user = await client.user.update({
        where: {
            number
        },
        data: {
            name,
            verified: true
        }
    })

    const token = jwt.sign({
        userId: user.id
    }, JWT_PASSWORD)

    res.json({
        token
    })

});

router.post("/signin", async (req, res) => {
    const number = req.body.number;
    const totp = getToken(number, "AUTH");
    try {

        const user = await client.user.findFirstOrThrow({
            where: {
                number
            }
        });

        if (process.env.NODE_ENV === "production") {
            try {
                await sendMessage(`Your otp for logging into latent is ${totp}`, number)
            } catch(e) {
                res.status(500).json({
                    message: "Could not send otp"
                })
                return   
            }
        }

        res.json({
            message: "Otp sent"
        })
    } catch(e) {
        res.status(411).json({
            message: "User invalid"
        })
    }
});

router.post("/signin/verify", async (req, res) => {
    const number = req.body.number;    
    const otp = req.body.totp;

    if (process.env.NODE_ENV === "production" && !verifyToken(number, "AUTH", otp)) {
        res.json({
            message: "Invalid token"
        })
        return
    }

    const user = await client.user.findFirstOrThrow({
        where: {
            number
        }
    })

    const token = jwt.sign({
        userId: user.id
    }, JWT_PASSWORD)

    res.json({
        token
    })

});

export default router;
