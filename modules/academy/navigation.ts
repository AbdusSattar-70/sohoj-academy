// One client-safe registry; no server/database imports. Each working route has one primary home.
type Route={href:string;label:[string,string];permission:string};
export const navigation:{group:[string,string];items:Route[]}[]=[
 {group:['Workspace','কর্মক্ষেত্র'],items:[{href:'/dashboard',label:['Dashboard','ড্যাশবোর্ড'],permission:''}]},
 {group:['CRM','সিআরএম'],items:[{href:'/dashboard/enquiries',label:['Enquiries & applications','অনুসন্ধান ও আবেদন'],permission:'people.view'}]},
 {group:['People','ব্যক্তি ও পরিচয়'],items:[{href:'/dashboard/people',label:['People directory','পরিচয় তালিকা'],permission:'people.view'},{href:'/dashboard/people/access',label:['Account access requests','প্রবেশাধিকারের অনুরোধ'],permission:'access.manage'}]},
 {group:['Academics','শিক্ষা পরিচালনা'],items:[{href:'/dashboard/offerings',label:['Offerings, batches & standard fees','Offering, ব্যাচ ও নির্ধারিত ফি'],permission:'academics.view'},{href:'/dashboard/programmes',label:['Programme definitions','প্রোগ্রামের ধরন'],permission:'academics.view'},{href:'/dashboard/directory',label:['Academic directory','শিক্ষার প্রয়োজনীয় তালিকা'],permission:'directory.view'}]},
 {group:['Settings & Help','সেটিংস ও সহায়তা'],items:[{href:'/dashboard/settings',label:['Setup & help','Setup ও সহায়তা'],permission:''}]},
];
export function currentRoute(path:string){return navigation.flatMap(g=>g.items).filter(r=>r.href==='/dashboard'?path===r.href:path===r.href||path.startsWith(r.href+'/')).sort((a,b)=>b.href.length-a.href.length)[0];}
