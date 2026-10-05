'use client';
import {createContext,useContext,useState,type ReactNode} from 'react';
type Division={id:string;name:string;nameBn:string;code:string};
const context=createContext<{division:string;setDivision:(id:string)=>void;divisions:Division[]}>({division:'',setDivision:()=>{},divisions:[]});
export function OperationScope({divisions,children}:{divisions:Division[];children:ReactNode}){const [division,setDivision]=useState('');return <context.Provider value={{division,setDivision,divisions}}>{children}</context.Provider>;}
export function useOperationScope(){return useContext(context);}
