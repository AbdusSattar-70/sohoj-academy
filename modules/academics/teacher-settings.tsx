'use client';
import {z} from 'zod';
import {ResourceRegister} from './resource-register';
const choices=z.object({teachers:z.array(z.object({id:z.string(),name:z.string()})),subjects:z.array(z.object({id:z.string(),name:z.string()})),rooms:z.array(z.object({id:z.string(),name:z.string()}))});
export function TeacherSettings({initial}:{initial:unknown}){const data=choices.parse(initial);return <ResourceRegister teachers={data.teachers} subjects={data.subjects} rooms={data.rooms}/>;}
