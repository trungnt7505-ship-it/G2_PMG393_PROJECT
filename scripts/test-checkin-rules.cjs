// Run against the local Firestore emulator, never a live project.
const fs = require('fs');
const root='http://127.0.0.1:8188/v1/projects/demo-cafe/databases/(default)/documents';
const base='projects/demo-cafe/databases/(default)/documents/';
const enc=x=>Buffer.from(JSON.stringify(x)).toString('base64url');
const token=enc({alg:'none',typ:'JWT'})+'.'+enc({sub:'customer',user_id:'customer',aud:'demo-cafe',iss:'https://securetoken.google.com/demo-cafe',iat:Math.floor(Date.now()/1000),exp:Math.floor(Date.now()/1000)+3600,firebase:{sign_in_provider:'password'}})+'.';
const value=x=>x instanceof Date?{timestampValue:x.toISOString()}:typeof x==='number'?{integerValue:String(x)}:x===null?{nullValue:null}:{stringValue:x};
const doc=(p,data)=>({name:base+p,fields:Object.fromEntries(Object.entries(data).map(([k,v])=>[k,value(v)]))});
async function commit(writes,auth='owner'){return fetch(root+':commit',{method:'POST',headers:{Authorization:'Bearer '+auth,'Content-Type':'application/json'},body:JSON.stringify({writes})})}
(async()=>{
const rules=fs.readFileSync('firebase/firestore.rules','utf8');
const upload=await fetch('http://127.0.0.1:8188/emulator/v1/projects/demo-cafe:securityRules',{method:'PUT',headers:{'Content-Type':'application/json'},body:JSON.stringify({rules:{files:[{name:'firestore.rules',content:rules}]}})});
if(!upload.ok)throw Error(await upload.text());
for(const scenario of ['valid','early','wrong-owner','wrong-secret','occupied']){
const now=new Date(), start=new Date(now.getTime()+(scenario==='early'?3600000:0));
const booking={customerId:scenario==='wrong-owner'?'other':'customer',tableId:scenario,status:'confirmed',startTime:start,holdUntil:new Date(start.getTime()+900000),sessionId:null};
let r=await commit([{update:doc('config/app',{checkInEarlyMinutes:15,sessionMinutes:120})},{update:doc('users/customer',{role:'customer',points:0})},{update:doc('tables/'+scenario,{status:scenario==='occupied'?'occupied':'available',qrSecret:'secret',currentSessionId:null})},{update:doc('reservations/'+scenario,booking)}]);if(!r.ok)throw Error(await r.text());
r=await commit([{update:doc('sessions/'+scenario,{customerId:'customer',openedBy:'customer',openedByRole:'customer',status:'active',tableId:scenario,tableQrSecret:scenario==='wrong-secret'?'bad':'secret',reservationId:scenario,startedAt:now,expiresAt:new Date(now.getTime()+7200000)})},{update:doc('reservations/'+scenario,{...booking,status:'checked_in',sessionId:scenario})},{update:doc('tables/'+scenario,{status:'occupied',qrSecret:'secret',currentSessionId:scenario})}],token);
if(r.ok!==(scenario==='valid'))throw Error(scenario+': '+r.status+' '+await r.text());
console.log('PASS '+scenario+' '+r.status);
}
})().catch(e=>{console.error(e);process.exit(1)});
