const express = require("express");
const cors = require("cors");

const app = express();
app.use(cors());

app.get("/health",(req,res)=>{
res.json({
   instance: process.env.INSTANCE_NAME,
   status:"OK",
   time:new Date().toISOString()
 });
});

app.listen(3000, () => {
console.log("Backend running");
});
