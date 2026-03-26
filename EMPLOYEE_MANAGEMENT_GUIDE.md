# Employee Management System - Migration & Testing Guide

## ✅ Completed Tasks

### 1. Extended Employee Fields Feature
- ✅ Created migration **043_add_employee_extended_fields.sql** with 11 new columns
- ✅ Updated **ManageEmployeeWindow.svelte** component with comprehensive form
- ✅ Implemented database persistence (saveNationality function)
- ✅ Implemented CV file upload handler with Supabase Storage integration
- ✅ Added success/error alert messages
- ✅ Added loading states for buttons during save operations
- ✅ Updated navigation in DesktopLayout
- ✅ Created migration runner script (run-043-migration.mjs)

### 2. New Form Fields (5 Sections)
**Basic Information** (Read-only)
- Name, Email, Phone, Role

**Personal Information**
- Date of Birth (date picker)
- Blood Group (dropdown: O+, O-, A+, A-, B+, B-, AB+, AB-)
- Aadhar Number (text)
- Resident Location (text)
- Education (textarea)

**Employment Information**
- Joining Date (date picker)
- Basic Salary (numeric input)
- Driving License Number (text)

**Bank Information**
- Bank Name (text)
- Bank Account Number (text)

**Documents**
- CV Upload (file input with Supabase Storage integration)

---

## 📋 Manual Migration Steps

Since network connectivity issues are preventing automated migration execution, follow these steps:

### Option A: Supabase Dashboard (Recommended)

1. **Open Supabase Dashboard**
   - Go to: https://supabase.com/dashboard
   - Select your project: "carwhiz"
   
2. **Navigate to SQL Editor**
   - Click "SQL Editor" in the left sidebar
   - Click "+ New Query"
   
3. **Copy & Execute Migration SQL**
   - Open: `supabase/migrations/043_add_employee_extended_fields.sql`
   - Copy all the SQL commands
   - Paste into the Supabase SQL Editor
   - Click "Run" (Ctrl+Enter)
   
4. **Verify Execution**
   - Look for success message at the bottom
   - If successful, you'll see: "Query executed successfully"

### Option B: psql Command Line

```powershell
# Using the database credentials from .env
$env:PGPASSWORD = "@Alzaidy123"
psql -h db.jlnntevahhmgzrkhuuta.supabase.co -U postgres -d postgres -f supabase/migrations/043_add_employee_extended_fields.sql
```

### Option C: Resolve Network Issues & Re-run Script

If you have network connectivity issues:

1. Check your internet connection
2. Verify firewall isn't blocking connections
3. Try running the migration script once more:
   ```powershell
   node scripts/run-043-migration.mjs
   ```

---

## 🧪 Testing the Feature

### After Migration is Applied:

#### 1. Test Employee Loading (Optional - automated)
- The getMana employee window now loads all extended fields from the database
- When you select an employee, it fetches: DOB, Blood Group, Education, Joining Date, License, Aadhar, Bank Details, CV URL

#### 2. Manual Form Testing
1. Start the dev server:
   ```powershell
   npm run dev
   ```

2. Log in to the application

3. Navigate to: **HR → Manage → Manage Employee**

4. **Test Search & Select**
   - Type employee name in search box
   - Click on employee to load their profile

5. **Test Form Fields**
   - Fill in: DOB, Blood Group, Education, Joining Date, Driving License, Aadhar
   - Fill in: Bank Name, Bank Account Number
   - Fill in: Basic Salary, Resident Location
   
6. **Test Save Functionality**
   - Click "💾 Save Changes" button
   - Expected result: Form shows "✓ Employee details saved successfully!" (green alert)
   - Data persists when you reload

7. **Test CV Upload**
   - Click "📤 Upload CV" button in Documents section
   - Select a PDF or Word document (max 5MB)
   - Expected result: Shows "✓ CV Uploaded" confirmation
   - File is uploaded to Supabase Storage

8. **Test Error Handling**
   - Try uploading file > 5MB → Shows error
   - Try uploading non-PDF/Word file → Shows error
   - Try saving with no employee selected → No action

---

## 🗄️ Database Schema Reference

### New Columns Added to `users` Table:

```sql
-- Data Fields
date_of_birth DATE
blood_group VARCHAR(5)
education TEXT
joining_date DATE
driving_license_number VARCHAR(100)
aadhar_number VARCHAR(20)
bank_account_number VARCHAR(50)
bank_name VARCHAR(100)
basic_salary NUMERIC(12, 2) DEFAULT 0
resident_location TEXT
cv_document_url TEXT

-- Audit Field
updated_by UUID REFERENCES public.users(id)
```

### Supabase Storage Structure:
```
documents/
└── cvs/
    └── {employee_id}/
        └── {timestamp}_{filename}
```

---

## 🔧 Implementation Details

### Frontend: ManageEmployeeWindow.svelte

**Key Functions:**
- `loadEmployees()` - Fetches all employees with extended fields
- `selectEmployee(emp)` - Loads employee details for editing
- `saveNationality()` - Persists form data to users table
- `handleFileUpload()` - Uploads CV to Supabase Storage

**State Variables:**
- `saving: boolean` - Tracks save/upload operations
- `successMessage: string` - Shows success alerts
- `error: string` - Shows error alerts

**Reactive Data Binding:**
- All form inputs use `bind:value` for two-way binding
- Changes sync automatically to `selectedEmployee` object

### File Upload Details:
- **Storage Bucket:** documents
- **Path Pattern:** cvs/{employee_id}/{timestamp}_{filename}
- **Allowed Types:** PDF, Word (.doc, .docx)
- **Max Size:** 5MB
- **Public URL:** Automatically generated and stored

---

## ❌ Troubleshooting

### Issue: Migration SQL Fails
**Solution:**
1. Check if columns already exist (idempotent SQL with IF NOT EXISTS)
2. Verify user has proper database permissions
3. Check Supabase logs for detailed errors

### Issue: CV Upload Fails
**Possible Causes:**
- Storage bucket "documents" doesn't exist
- Employee ID not properly set
- File type/size validation failed

**Solution:**
1. Verify storage bucket exists in Supabase
2. Check browser console for detailed error
3. Ensure service role key has storage permissions

### Issue: Save Button Disabled
**Cause:** `saving` state is true (operation in progress)
**Solution:** Wait for operation to complete, button text will show "💾 Save Changes"

### Issue: Form Data Not Loaded
**Possible Cause:** Migration hasn't been executed yet, columns don't exist
**Solution:** Execute migration first before testing

---

## 📊 Next Steps (Optional Enhancements)

1. **Add Validation:**
   - Format validation for Aadhar (12 digits)
   - Format validation for bank account
   - Email validation

2. **Add Download/View CV:**
   - Add button to view uploaded CV
   - Add button to download CV

3. **Add Bulk Actions:**
   - Bulk edit basic salary
   - Bulk update joining dates

4. **Add Search/Filter:**
   - Filter by joining date range
   - Filter by blood group
   - Filter by department/role

5. **Add Audit Trail:**
   - Show who last updated employee record
   - Show timestamp of last update
   - Show change history

---

## 📝 Important Notes

- Migration uses `IF NOT EXISTS` for all columns (safe to run multiple times)
- All fields are optional in the database schema
- CV uploads stored as public URLs in Supabase Storage
- Form uses audit fields (`updated_by`) for tracking changes
- Blood group stored as VARCHAR(5) to accommodate: O+, O-, A+, A-, B+, B-, AB+, AB-

---

**Status:** ✅ Ready for manual migration execution and testing
**Last Updated:** $(date)
