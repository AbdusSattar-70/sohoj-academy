/** Normalize a statement export, never interpret source-specific debit/credit conventions. */
export function parseStatementCsv(text:string){
 if(text.length>250000)throw Error("Maximum statement size is 250 KB; split larger files.");
 text=text.replace(/^\uFEFF/,"");
 const rows:string[][]=[];let row:string[]=[],field="",quoted=false;
 for(let i=0;i<text.length;i++){const c=text[i];if(c==='"'){if(quoted&&text[i+1]==='"'){field+='"';i++;}else if(quoted||field==='')quoted=!quoted;else throw Error("Invalid CSV quoting.");}else if(c===','&&!quoted){row.push(field);field="";}else if((c==='\n'||c==='\r')&&!quoted){if(c==='\r'&&text[i+1]==='\n')i++;row.push(field);if(row.some(v=>v.trim()))rows.push(row);row=[];field="";}else field+=c;}
 if(quoted)throw Error("Unclosed CSV quote.");row.push(field);if(row.some(v=>v.trim()))rows.push(row);
 if(rows.length<2||rows.length>251)throw Error("Provide a header and 1–250 transactions.");const header=rows.shift()!.map(v=>v.replace(/^\uFEFF/,"").trim().toLowerCase());if(header.join(",")!=="date,reference,amount,description")throw Error("Required header: date,reference,amount,description. Amount is positive for money in, negative for money out.");
 return rows.map((r,i)=>{if(r.length!==4||!/^\d{4}-\d{2}-\d{2}$/.test(r[0].trim())||!/^[-+]?\d+(?:\.\d{1,2})?$/.test(r[2].trim()))throw Error(`Check row ${i+2}: date, reference, signed amount and description.`);return {date:r[0].trim(),reference:r[1].trim(),amount:Number(r[2]),description:r[3].trim()};});
}
