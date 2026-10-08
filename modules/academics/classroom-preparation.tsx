'use client';
import {inputClass,useWords} from '@/modules/academy/components/common';
import {createClassroom} from './actions';
import {OperationForm} from './operation-form';
export function ClassroomPreparation({onCreated,onCancel}:{onCreated:(room:{id:string;name:string;capacity:number})=>void;onCancel:()=>void}){
 const t=useWords();
 return <OperationForm title={t('Create missing classroom','অনুপস্থিত শ্রেণিকক্ষ তৈরি')} reasonOptions={['Confirmed classroom name and available seats']} save={async input=>{const result=await createClassroom(input);if(result.ok&&result.room)onCreated(result.room);return result;}} onSaved={async()=>{}} onCancel={onCancel} serialize={fd=>({name:String(fd.get('name')),capacity:Number(fd.get('capacity'))})}><label>{t('Classroom name','শ্রেণিকক্ষের নাম')}<input className={inputClass} name="name" required minLength={2} maxLength={160}/></label><label>{t('Seats','আসন')}<input className={inputClass} name="capacity" required type="number" min={1} max={500} defaultValue={12}/></label><p>{t('The scheduling form stays open. Saving selects this room; availability and booking checks still apply.','Scheduling form খোলা থাকবে। সংরক্ষণের পর এই room নির্বাচিত হবে; availability ও booking যাচাই হবে।')}</p></OperationForm>;
}
