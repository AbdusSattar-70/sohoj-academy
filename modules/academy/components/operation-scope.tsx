'use client';
import {createContext,useContext,useState,type ReactNode} from 'react';
import {useRouter} from 'next/navigation';
import {selectAccountWorkspace} from '@/modules/access/session-actions';
type Division={id:string;name:string;nameBn:string;code:string};
const context=createContext<{division:string;setDivision:(id:string)=>Promise<boolean>;divisions:Division[];busy:boolean;error:string}>({division:'',setDivision:async()=>false,divisions:[],busy:false,error:''});
// Server cookie selects a workspace; the DB checks account assignments on every request.
export function OperationScope({divisions,initialDivision,children}:{divisions:Division[];initialDivision:string;accountId:string;children:ReactNode}){
 const router=useRouter(),[busy,setBusy]=useState(false),[error,setError]=useState('');
 const division=divisions.some(d=>d.id===initialDivision)?initialDivision:'';
 async function setDivision(id:string){
  if(busy||!divisions.some(d=>d.id===id))return false;
  setBusy(true);setError('');
  try{const result=await selectAccountWorkspace(id);if(!result.ok){setError(result.message);return false;}router.refresh();return true;}catch{setError('Workspace change could not be confirmed. Please retry.');return false;}finally{setBusy(false);}
 }
 return <context.Provider value={{division,setDivision,divisions,busy,error}}>{children}</context.Provider>;
}
export function useOperationScope(){return useContext(context);}
