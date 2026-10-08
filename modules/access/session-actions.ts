'use server';
import {cookies} from 'next/headers';
import {academyClient} from '@/modules/academy/client';
import {academyContext} from '@/modules/academy/queries';
import {databaseId} from '@/lib/database-id';
export async function signOutAccount(){
 const {error}=await(await academyClient()).auth.signOut({scope:'local'});
 if(error)return{ok:false,message:'Sign out could not be confirmed. Please retry.'};
 (await cookies()).delete('sohoj-workspace');
 return{ok:true,message:'Signed out.'};
}
export async function selectAccountWorkspace(id:string){
 if(!databaseId.safeParse(id).success)return{ok:false,message:'Select an available workspace.'};
 const context=await academyContext();
 if(!context?.divisions.some(d=>d.id===id))return{ok:false,message:'This workspace is not assigned to your account.'};
 (await cookies()).set('sohoj-workspace',id,{httpOnly:true,secure:process.env.NODE_ENV==='production',sameSite:'lax',path:'/'});
 return{ok:true,message:'Workspace selected.'};
}
