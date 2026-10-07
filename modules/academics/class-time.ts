// Clock access belongs to event/request handlers, not stored academic dates.
export function bangladeshToday(){return new Date(Date.now()+6*3600000).toISOString().slice(0,10);}
export function localClassTime(value:string){return new Date(new Date(value).getTime()+6*3600000).toISOString().slice(0,16);}
