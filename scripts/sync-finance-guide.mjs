import {readFile,writeFile} from 'node:fs/promises';
const guide=JSON.parse(await readFile(new URL('../modules/help/finance-guide.bn.json',import.meta.url),'utf8'));
let markdown=`# ${guide.title}\n\n${guide.intro}\n\nএই নির্দেশিকা একই বিষয়বস্তু থেকে ERP-এর \`/dashboard/help/finance\` পৃষ্ঠায় দেখানো হয়। নিচের কাজের লিংকগুলো ERP-এর নিজের ডোমেইন থেকে খুলতে হবে।\n`;
for(const section of guide.sections){markdown+=`\n## ${section.title}\n\n${section.paragraphs.join('\n\n')}\n`;if(section.links.length)markdown+='\n'+section.links.map(link=>`- [${link.label}](${link.href})`).join('\n')+'\n';}
await writeFile(new URL('../docs/architecture/FINANCE_OPERATOR_GUIDE_BN.md',import.meta.url),markdown);
