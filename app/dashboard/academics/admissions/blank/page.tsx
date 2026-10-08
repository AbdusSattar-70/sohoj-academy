import {admissionOptions} from '@/modules/admissions/actions';
import {AdmissionPaper} from '@/modules/admissions/admission-paper';
import {PrintControls} from '@/modules/admissions/print-controls';
export default async function Page(){return <><PrintControls back="/dashboard/academics/admissions"/><AdmissionPaper options={await admissionOptions()}/></>;}
