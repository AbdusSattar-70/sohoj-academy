import {billingRegister} from '@/modules/admissions/actions';
import {BillingRegister} from '@/modules/admissions/billing-register';
export default async function Page(){return <BillingRegister initial={await billingRegister()}/>;}
