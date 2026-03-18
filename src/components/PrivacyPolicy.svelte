<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  const dispatch = createEventDispatcher();
</script>

<div class="pp-overlay" on:click|self={() => dispatch('close')} on:keydown={() => {}} role="button" tabindex="-1">
  <div class="pp-container">
    <div class="pp-header">
      <h1>Privacy Policy</h1>
      <button class="pp-close" on:click={() => dispatch('close')} aria-label="Close">&times;</button>
    </div>

    <div class="pp-content">
      <p class="pp-updated">Last updated: 17 March 2026</p>

      <section>
        <h2>1. Introduction</h2>
        <p>CarWhizz ("we", "our", "us") is a business management application designed for automotive businesses in India. This Privacy Policy explains how we collect, use, store, and protect your personal data in compliance with applicable Indian laws including:</p>
        <ul>
          <li>The Digital Personal Data Protection Act, 2023 (DPDP Act)</li>
          <li>The Information Technology Act, 2000 (IT Act)</li>
          <li>The Information Technology (Reasonable Security Practices and Procedures and Sensitive Personal Data or Information) Rules, 2011 (SPDI Rules)</li>
        </ul>
      </section>

      <section>
        <h2>2. Data We Collect</h2>
        <p>We collect and process the following categories of data:</p>
        <h3>2.1 Personal Data</h3>
        <ul>
          <li>Employee names, contact numbers, and email addresses</li>
          <li>Customer and vendor names, phone numbers, and addresses</li>
          <li>User access codes for authentication</li>
          <li>Attendance records (check-in/check-out timestamps)</li>
        </ul>
        <h3>2.2 Business Data</h3>
        <ul>
          <li>Sales and purchase transaction records</li>
          <li>Financial ledger entries and accounting data</li>
          <li>Product and vehicle inventory information</li>
          <li>Asset and depreciation records</li>
        </ul>
        <h3>2.3 Technical Data</h3>
        <ul>
          <li>Device type and browser information</li>
          <li>Audit logs of system actions (who created/modified records)</li>
        </ul>
      </section>

      <section>
        <h2>3. Purpose of Data Collection</h2>
        <p>Your data is collected and processed for the following legitimate purposes:</p>
        <ul>
          <li>Managing day-to-day business operations (billing, inventory, finance)</li>
          <li>Recording employee attendance via QR-based check-in/check-out</li>
          <li>Generating financial reports compliant with Indian Accounting Standards (Ind AS) and Schedule III of the Companies Act, 2013</li>
          <li>Maintaining audit trails as required by applicable regulations</li>
          <li>User authentication and access control</li>
        </ul>
      </section>

      <section>
        <h2>4. Legal Basis for Processing</h2>
        <p>Under the DPDP Act, 2023, we process personal data based on:</p>
        <ul>
          <li><strong>Consent:</strong> You provide consent when you use the application and enter your data</li>
          <li><strong>Legitimate Use:</strong> Processing necessary for the performance of business operations and compliance with legal obligations under the Income Tax Act, GST Act, and Companies Act</li>
        </ul>
      </section>

      <section>
        <h2>5. Data Storage and Security</h2>
        <p>We implement reasonable security practices as required under the SPDI Rules, 2011:</p>
        <ul>
          <li>All data is stored securely on Supabase cloud infrastructure with encryption at rest and in transit (TLS/SSL)</li>
          <li>Row Level Security (RLS) policies restrict data access at the database level</li>
          <li>Access codes are used for user authentication</li>
          <li>Audit logs track all data modifications with user attribution</li>
          <li>Role-based permissions control access to different application features</li>
        </ul>
      </section>

      <section>
        <h2>6. Data Retention</h2>
        <p>We retain your data for the following periods in accordance with Indian law:</p>
        <ul>
          <li><strong>Financial records:</strong> Minimum 8 years as required under the Income Tax Act, 1961 (Section 44AA) and GST laws</li>
          <li><strong>Audit logs:</strong> Retained for 8 years from the date of creation</li>
          <li><strong>Employee records:</strong> Retained for the duration of employment and 5 years thereafter</li>
          <li><strong>Customer/Vendor records:</strong> Retained as long as there are outstanding transactions, and for 8 years after the last transaction</li>
        </ul>
      </section>

      <section>
        <h2>7. Your Rights under the DPDP Act, 2023</h2>
        <p>As a Data Principal, you have the following rights:</p>
        <ul>
          <li><strong>Right to Access:</strong> You may request a summary of your personal data being processed</li>
          <li><strong>Right to Correction and Erasure:</strong> You may request correction of inaccurate data or erasure of data no longer necessary for the purpose it was collected, subject to legal retention requirements</li>
          <li><strong>Right to Grievance Redressal:</strong> You may raise grievances regarding data processing to our Data Protection Officer</li>
          <li><strong>Right to Nominate:</strong> You may nominate another person to exercise your rights in case of death or incapacity</li>
        </ul>
      </section>

      <section>
        <h2>8. Data Sharing and Disclosure</h2>
        <p>We do not sell your personal data. Data may be shared only in the following circumstances:</p>
        <ul>
          <li>With authorised employees who need access for business operations</li>
          <li>With government authorities when required under applicable Indian laws (Income Tax, GST, etc.)</li>
          <li>With our cloud infrastructure provider (Supabase) for data hosting, governed by their data processing agreement</li>
        </ul>
      </section>

      <section>
        <h2>9. Cookies and Tracking</h2>
        <p>CarWhizz uses only essential local storage and session data for authentication and user interface preferences. We do not use third-party tracking cookies or analytics.</p>
      </section>

      <section>
        <h2>10. Children's Data</h2>
        <p>CarWhizz is a business management tool not intended for use by individuals under 18 years of age. We do not knowingly collect personal data from children.</p>
      </section>

      <section>
        <h2>11. Data Breach Notification</h2>
        <p>In the event of a personal data breach, we will:</p>
        <ul>
          <li>Notify the Data Protection Board of India as required under Section 8 of the DPDP Act, 2023</li>
          <li>Notify affected Data Principals without unreasonable delay</li>
          <li>Take immediate steps to mitigate the breach and prevent recurrence</li>
        </ul>
      </section>

      <section>
        <h2>12. Grievance Officer</h2>
        <p>In accordance with the IT Act, 2000 and the DPDP Act, 2023, the Grievance Officer for data-related concerns is:</p>
        <div class="pp-contact">
          <p><strong>CarWhizz Data Protection Officer</strong></p>
          <p>Email: privacy@carwhizz.com</p>
          <p>Response time: Within 30 days of receiving the complaint</p>
        </div>
      </section>

      <section>
        <h2>13. Changes to This Policy</h2>
        <p>We may update this Privacy Policy from time to time. Any changes will be reflected with an updated "Last updated" date. Continued use of the application after changes constitutes acceptance of the revised policy.</p>
      </section>

      <section>
        <h2>14. Governing Law</h2>
        <p>This Privacy Policy is governed by and construed in accordance with the laws of India. Any disputes arising out of this policy shall be subject to the exclusive jurisdiction of courts in India.</p>
      </section>
    </div>
  </div>
</div>

<style>
  .pp-overlay {
    position: fixed;
    top: 0; left: 0; right: 0; bottom: 0;
    background: rgba(0,0,0,0.5);
    z-index: 9999;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 16px;
    overflow-y: auto;
  }

  .pp-container {
    background: #fff;
    border-radius: 16px;
    width: 100%;
    max-width: 720px;
    max-height: 90vh;
    display: flex;
    flex-direction: column;
    box-shadow: 0 20px 60px rgba(0,0,0,0.3);
    animation: ppSlideUp 0.3s ease-out;
  }

  @keyframes ppSlideUp {
    from { opacity: 0; transform: translateY(30px); }
    to { opacity: 1; transform: translateY(0); }
  }

  .pp-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 20px 24px;
    border-bottom: 1px solid #e2e8f0;
    flex-shrink: 0;
  }

  .pp-header h1 {
    margin: 0;
    font-size: 20px;
    font-weight: 700;
    color: #1a202c;
  }

  .pp-close {
    background: none;
    border: none;
    font-size: 28px;
    cursor: pointer;
    color: #718096;
    line-height: 1;
    padding: 0 4px;
  }

  .pp-close:hover { color: #e53e3e; }

  .pp-content {
    padding: 24px;
    overflow-y: auto;
    font-size: 14px;
    line-height: 1.7;
    color: #2d3748;
  }

  .pp-updated {
    font-size: 13px;
    color: #718096;
    font-style: italic;
    margin: 0 0 20px 0;
  }

  .pp-content h2 {
    font-size: 16px;
    font-weight: 700;
    color: #C41E3A;
    margin: 24px 0 8px;
  }

  .pp-content h2:first-of-type { margin-top: 0; }

  .pp-content h3 {
    font-size: 14px;
    font-weight: 600;
    color: #2d3748;
    margin: 12px 0 4px;
  }

  .pp-content p { margin: 6px 0; }

  .pp-content ul {
    margin: 6px 0 6px 20px;
    padding: 0;
  }

  .pp-content li {
    margin-bottom: 4px;
  }

  .pp-contact {
    background: #fff7ed;
    border: 1px solid #fed7aa;
    border-radius: 8px;
    padding: 12px 16px;
    margin: 8px 0;
  }

  .pp-contact p { margin: 2px 0; }

  section { margin-bottom: 8px; }

  @media (max-width: 480px) {
    .pp-container {
      max-height: 95vh;
      border-radius: 12px;
    }
    .pp-header { padding: 16px; }
    .pp-header h1 { font-size: 18px; }
    .pp-content { padding: 16px; font-size: 13px; }
    .pp-content h2 { font-size: 15px; }
  }
</style>
