const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  'https://mxvmrilzzpckpwwluqaa.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im14dm1yaWx6enBja3B3d2x1cWFhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjUxOTgwMzQsImV4cCI6MjA0MDc3NDAzNH0.Zt7KnqGCGhWgJGfGQKnOdMNQhPWZJOJdMjGPLXEWHPM'
);

async function testFunction() {
  try {
    console.log('Testing start_dish_cooking_batch function...');
    
    // Try to call the function with a test dish ID
    const { data, error } = await supabase
      .rpc('start_dish_cooking_batch', {
        p_dish_id: '00000000-0000-0000-0000-000000000000', // fake UUID
        p_batch_date: '2024-10-03'
      });
    
    console.log('Function result:', { data, error });
    
    if (error) {
      console.log('Error details:', JSON.stringify(error, null, 2));
    }
    
  } catch (err) {
    console.error('Exception:', err);
  }
}

testFunction();
