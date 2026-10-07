'use client';
import { useCallback,useEffect,useRef,useState } from 'react';
import { z } from 'zod';
import { searchAcademy } from '../actions';
export function useRegister<T>(target:Parameters<typeof searchAcademy>[0],schema:z.ZodType<{rows:T[];page:number;total:number;pageSize:number}>,filter:Record<string,unknown>={}) {
 const [data,setData]=useState<{rows:T[];page:number;total:number;pageSize:number}>({rows:[],page:1,total:0,pageSize:25});
 const [loading,setLoading]=useState(true),[error,setError]=useState(false),[query,setQuery]=useState('');
 const initialLoad=useRef<typeof load|undefined>(undefined);
 const generation=useRef(0),current=useRef({query:'',page:1});const signature=JSON.stringify(filter);
 const load=useCallback(async(page=current.current.page,needle=current.current.query)=>{
  const sequence=++generation.current;current.current={query:needle,page};setLoading(true);setError(false);
  try{const value=schema.parse(await searchAcademy(target,{...JSON.parse(signature),query:needle,page}));if(sequence===generation.current)setData(value);}
  catch{if(sequence===generation.current)setError(true);}finally{if(sequence===generation.current)setLoading(false);}
 },[target,schema,signature]);
 useEffect(()=>{if(initialLoad.current===load)return;initialLoad.current=load;void load(1,'');},[load]);
 return {data,loading,error,query,setQuery,load};
}
