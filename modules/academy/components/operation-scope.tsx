'use client';
import {createContext,useContext,useSyncExternalStore,type ReactNode} from 'react';
type Division={id:string;name:string;nameBn:string;code:string};
const context=createContext<{division:string;setDivision:(id:string)=>void;divisions:Division[]}>({division:'',setDivision:()=>{},divisions:[]});
// This preference filters the workspace; database permissions remain authoritative.
const sessionFallback=new Map<string,string>();
export function OperationScope({divisions,accountId,children}:{divisions:Division[];accountId:string;children:ReactNode}){
 const key=`sohoj-session-workspace:${accountId}`;
 const division=useSyncExternalStore(listener=>{
  window.addEventListener('sohoj-workspace-change',listener);
  return()=>window.removeEventListener('sohoj-workspace-change',listener);
 },()=>{
  let value=sessionFallback.get(key)??'';
  try{value=sessionStorage.getItem(key)??value;}catch{/* Use the in-memory session preference if storage is unavailable. */}
  return divisions.some(d=>d.id===value)?value:'';
 },()=>'');
 function setDivision(id:string){
  if(!divisions.some(d=>d.id===id))return;
  sessionFallback.set(key,id);
  try{sessionStorage.setItem(key,id);}catch{/* The fallback supports this tab without storage. */}
  window.dispatchEvent(new Event('sohoj-workspace-change'));
 }
 return <context.Provider value={{division,setDivision,divisions}}>{children}</context.Provider>;
}
export function useOperationScope(){return useContext(context);}
