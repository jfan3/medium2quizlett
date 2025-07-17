const fs = require('fs');
const path = require('path');

// Read the migration file
const migrationSQL = fs.readFileSync(path.join(__dirname, 'database_migration_v2.sql'), 'utf8');

// Supabase project details
const SUPABASE_URL = 'https://ongdpixggfbbcdpunuxh.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9uZ2RwaXhnZ2ZiYmNkcHVudXhoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzU4NjIzNTksImV4cCI6MjA1MTQzODM1OX0.Osg5zBmIaGQonJDCM_87Usp5CjEa5YBFJhyXYrWA6r8';

// For running migrations, we need to use the service role key from environment
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9uZ2RwaXhnZ2ZiYmNkcHVudXhoIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTczNTg2MjM1OSwiZXhwIjoyMDUxNDM4MzU5fQ.IXMrJ5awqRFZSN5sGMqC94ChUBGXQD7WJRxSNR1ITbY';

async function runMigration() {
    console.log('Starting database migration...');
    
    // Split the migration into individual statements
    const statements = migrationSQL
        .split(';')
        .map(s => s.trim())
        .filter(s => s.length > 0 && !s.startsWith('--'));
    
    let successCount = 0;
    let errorCount = 0;
    
    for (let i = 0; i < statements.length; i++) {
        const statement = statements[i] + ';';
        
        // Skip pure comment lines
        if (statement.trim().startsWith('--')) continue;
        
        try {
            const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/exec_sql`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'apikey': SUPABASE_SERVICE_KEY,
                    'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`,
                    'Prefer': 'return=minimal'
                },
                body: JSON.stringify({ query: statement })
            });
            
            if (!response.ok) {
                const error = await response.text();
                console.error(`Error in statement ${i + 1}: ${error}`);
                console.error(`Statement: ${statement.substring(0, 100)}...`);
                errorCount++;
            } else {
                successCount++;
                console.log(`✓ Statement ${i + 1} executed successfully`);
            }
        } catch (error) {
            console.error(`Error in statement ${i + 1}: ${error.message}`);
            errorCount++;
        }
    }
    
    console.log(`\nMigration completed: ${successCount} successful, ${errorCount} errors`);
}

// Check if we can connect to Supabase first
async function checkConnection() {
    try {
        const response = await fetch(`${SUPABASE_URL}/rest/v1/`, {
            headers: {
                'apikey': SUPABASE_ANON_KEY,
            }
        });
        
        if (response.ok) {
            console.log('✓ Connected to Supabase');
            return true;
        } else {
            console.error('✗ Failed to connect to Supabase');
            return false;
        }
    } catch (error) {
        console.error('✗ Connection error:', error.message);
        return false;
    }
}

// Main execution
(async () => {
    if (await checkConnection()) {
        console.log('\nNote: Some statements might fail if tables/columns already exist. This is expected.');
        await runMigration();
    }
})();