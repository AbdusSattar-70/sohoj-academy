'use client';
import {createContext,useContext,useSyncExternalStore,type ReactNode} from 'react';
type Division={id:string;name:string;nameBn:string;code:string};
const context=createContext<{division:string;setDivision:(id:string)=>void;divisions:Division[]}>({division:'',setDivision:()=>{},divisions:[]});
export function OperationScope({divisions,accountId,children}:{divisions:Division[];accountId:string;children:ReactNode}){
 const key=`sohoj-working-division:${accountId}`;
 const division=useSyncExternalStore(listener=>{window.addEventListener('sohoj-workspace-change',listener);window.addEventListener('storage',listener);return()=>{window.removeEventListener('sohoj-workspace-change',listener);window.removeEventListener('storage',listener);};},()=>{try{const value=localStorage.getItem(key)??'';return divisions.some(d=>d.id===value)?value:'';}catch{return '';}},()=>'');
 function setDivision(id:string){if(id&&!divisions.some(d=>d.id===id))return;try{localStorage.setItem(key,id);window.dispatchEvent(new Event('sohoj-workspace-change'));}catch{/* Optional preference; restricted storage does not grant access. */}}
 return <context.Provider value={{division,setDivision,divisions}}>{children}</context.Provider>;
}
export function useOperationScope(){return useContext(context);}
