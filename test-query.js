// Test script to debug Supabase queries
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://mxvmrilzzpckpwwluqaa.supabase.co'
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im14dm1yaWx6enBja3B3d2x1cWFhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY4MTIxMzAsImV4cCI6MjA3MjM4ODEzMH0.5VrjBv0kesitUQ_E_uCRLIsv351iPyeEgqqq5pvrNAA'

const supabase = createClient(supabaseUrl, supabaseAnonKey)

async function testQueries() {
  console.log('Testing basic queries...')
  
  // Test 1: Simple token_wallets query
  try {
    const { data, error } = await supabase
      .from('token_wallets')
      .select('*')
      .eq('user_id', 'f7886c95-23c3-4e6a-a976-08d24b9a17e1')
    
    console.log('Token wallets query:', { data, error })
  } catch (err) {
    console.error('Token wallets error:', err)
  }
  
  // Test 2: Simple user_carts query
  try {
    const { data, error } = await supabase
      .from('user_carts')
      .select('*')
      .eq('user_id', 'f7886c95-23c3-4e6a-a976-08d24b9a17e1')
    
    console.log('User carts query:', { data, error })
  } catch (err) {
    console.error('User carts error:', err)
  }
  
  // Test 3: Protein options query
  try {
    const { data, error } = await supabase
      .from('protein_options')
      .select('*')
    
    console.log('Protein options query:', { data, error })
  } catch (err) {
    console.error('Protein options error:', err)
  }
  
  // Test 4: Dish protein options query
  try {
    const { data, error } = await supabase
      .from('dish_protein_options')
      .select('*')
    
    console.log('Dish protein options query:', { data, error })
  } catch (err) {
    console.error('Dish protein options error:', err)
  }
}

testQueries()
