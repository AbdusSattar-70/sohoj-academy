type Identity = {person_no:number;staff_no?:number|null;referrer_no?:number|null};
export function personIdentity(person:Identity,role='') {
 const staff=person.staff_no==null?null:`SA-STF-${String(person.staff_no).padStart(5,'0')}`;
 const referrer=person.referrer_no==null?null:`SA-RFR-${String(person.referrer_no).padStart(5,'0')}`;
 if(role==='REFERRER'&&referrer)return referrer;
 if((role==='STAFF'||role==='TEACHER')&&staff)return staff;
 return [staff,referrer].filter(Boolean).join(' · ')||`P-${person.person_no}`;
}
