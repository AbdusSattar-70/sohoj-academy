export const academicSettingsSections=[
 {id:'years',en:'Academic years',bn:'শিক্ষাবর্ষ',descriptionEn:'Review the operating year and dates.',descriptionBn:'শিক্ষাবর্ষ ও তারিখ যাচাই করুন।',permission:'directory.view',group:'foundation'},
 {id:'subjects',en:'Subjects',bn:'বিষয়',descriptionEn:'Choose the subjects the academy teaches.',descriptionBn:'যেসব বিষয় পড়ানো হবে সেগুলো ঠিক করুন।',permission:'directory.view',group:'foundation'},
 {id:'groups',en:'Class groups',bn:'ক্লাসের বিভাগ',descriptionEn:'Science and other eligibility groups.',descriptionBn:'বিজ্ঞান ও অন্যান্য যোগ্যতার বিভাগ।',permission:'directory.view',group:'foundation'},
 {id:'schools',en:'Schools & colleges',bn:'স্কুল ও কলেজ',descriptionEn:'Manage institution choices used on applications.',descriptionBn:'আবেদনে ব্যবহৃত প্রতিষ্ঠানের তালিকা পরিচালনা করুন।',permission:'directory.view',group:'foundation'},
 {id:'names',en:'Programme names',bn:'প্রোগ্রামের নাম',descriptionEn:'Reusable names such as SSC Preparation.',descriptionBn:'এসএসসি প্রস্তুতির মতো পুনর্ব্যবহারযোগ্য নাম।',permission:'academics.view',group:'foundation'},
 {id:'choices',en:'Other application choices',bn:'আবেদনের অন্যান্য তালিকা',descriptionEn:'Areas, guardian relationships and other shared options.',descriptionBn:'এলাকা, অভিভাবকের সম্পর্ক ও অন্যান্য প্রয়োজনীয় তালিকা।',permission:'directory.view',group:'foundation'},
 {id:'rooms',en:'Classrooms',bn:'শ্রেণিকক্ষ',descriptionEn:'Room names, seats and active status.',descriptionBn:'শ্রেণিকক্ষের নাম, আসন ও সক্রিয় অবস্থা।',permission:'academics.manage',group:'teaching'},
 {id:'teachers',en:'Teacher subjects & leave',bn:'শিক্ষকের বিষয় ও ছুটি',descriptionEn:'Verify subject qualifications and unavailable dates.',descriptionBn:'বিষয়ের যোগ্যতা ও অনুপলব্ধ তারিখ যাচাই করুন।',permission:'academics.manage',group:'teaching'},
 {id:'availability',en:'Weekly availability',bn:'সাপ্তাহিক সময়',descriptionEn:'When each teacher and classroom can be used.',descriptionBn:'কোন সময়ে শিক্ষক ও শ্রেণিকক্ষ ব্যবহার করা যাবে।',permission:'academics.manage',group:'teaching'},
 {id:'holidays',en:'Holidays & closures',bn:'ছুটি ও বন্ধের দিন',descriptionEn:'Exclude dates when classes should not run.',descriptionBn:'যেসব দিনে ক্লাস হবে না সেগুলো ঠিক করুন।',permission:'academics.manage',group:'teaching'},
 {id:'contacts',en:'Class notification contacts',bn:'ক্লাসের বার্তা পাওয়ার ঠিকানা',descriptionEn:'Guardian or adult email contacts with consent.',descriptionBn:'সম্মত অভিভাবক বা প্রাপ্তবয়স্কের ইমেইল ঠিকানা।',permission:'academics.manage',group:'communication'},
 {id:'emails',en:'Email delivery status',bn:'ইমেইল পাঠানোর অবস্থা',descriptionEn:'Inspect pending and failed class messages.',descriptionBn:'অপেক্ষমান ও ব্যর্থ ক্লাসের বার্তা দেখুন।',permission:'academics.manage',group:'communication'},
] as const;
export type AcademicSettingsSection=typeof academicSettingsSections[number]['id'];
