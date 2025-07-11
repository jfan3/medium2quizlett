const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');

// Read env_config.txt
const envContent = fs.readFileSync('env_config.txt', 'utf8');
const envVars = {};
envContent.split('\n').forEach(line => {
  const [key, value] = line.split('=');
  if (key && value) {
    envVars[key.trim()] = value.trim();
  }
});

const supabaseUrl = envVars.SUPABASE_URL;
const supabaseServiceKey = envVars.SUPABASE_ANON_KEY;

console.log('URL:', supabaseUrl);
console.log('Key exists:', !!supabaseServiceKey);

if (!supabaseUrl || !supabaseServiceKey) {
  console.error('Missing Supabase credentials');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function checkRSSSources() {
  const { data, error } = await supabase
    .from('rss_sources')
    .select('*');
  
  if (error) {
    console.error('Error:', error);
  } else {
    console.log(`Found ${data.length} RSS sources in database`);
    if (data.length > 0) {
      console.log('\nAll sources with topics:');
      data.forEach(source => {
        console.log(`- ${source.name}`);
        console.log(`  Topics: ${JSON.stringify(source.topics)}`);
        console.log(`  URL: ${source.url}`);
      });
    }
  }
}

checkRSSSources();