-- Add explicit logging to the trigger to debug why admin profile isn't being created

CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_first_name TEXT;
    v_last_name TEXT;
    v_phone TEXT;
    v_delivery_group delivery_group;
    v_admin_role TEXT;
BEGIN
    RAISE NOTICE 'Trigger fired for user: %', NEW.id;
    RAISE NOTICE 'User metadata: %', NEW.raw_user_meta_data;
    
    -- Extract common metadata
    v_first_name := NULLIF(TRIM(COALESCE(NEW.raw_user_meta_data->>'first_name', '')), '');
    v_last_name := NULLIF(TRIM(COALESCE(NEW.raw_user_meta_data->>'last_name', '')), '');
    
    -- Check if this is an ADMIN signup (has admin_role in metadata)
    v_admin_role := NEW.raw_user_meta_data->>'admin_role';
    
    RAISE NOTICE 'Admin role detected: %', v_admin_role;
    
    IF v_admin_role IS NOT NULL THEN
        RAISE NOTICE 'Creating ADMIN user profile for: %', NEW.email;
        
        -- Validate role
        IF v_admin_role NOT IN ('root', 'admin', 'manager') THEN
            v_admin_role := 'admin';
        END IF;
        
        -- Insert into admin_users table
        INSERT INTO public.admin_users (
            id,
            email,
            first_name,
            last_name,
            role,
            is_active,
            created_at,
            updated_at
        )
        VALUES (
            NEW.id,
            NEW.email,
            COALESCE(v_first_name, 'Admin'),
            COALESCE(v_last_name, 'User'),
            v_admin_role,
            true,
            NOW(),
            NOW()
        );
        
        RAISE NOTICE 'Admin user profile created successfully';
        
    ELSE
        RAISE NOTICE 'Creating REGULAR user profile for: %', NEW.email;
        
        v_phone := NULLIF(TRIM(COALESCE(NEW.raw_user_meta_data->>'phone', '')), '');
        
        -- Only set delivery_group if it's provided and valid
        IF NEW.raw_user_meta_data->>'delivery_group' IS NOT NULL 
           AND NEW.raw_user_meta_data->>'delivery_group' IN ('1', '2', '3', '4') THEN
            v_delivery_group := (NEW.raw_user_meta_data->>'delivery_group')::delivery_group;
        ELSE
            v_delivery_group := NULL;
        END IF;
        
        -- Insert into public.users table
        INSERT INTO public.users (
            id,
            email,
            first_name,
            last_name,
            phone,
            delivery_group,
            group_assigned,
            is_active
        )
        VALUES (
            NEW.id,
            NEW.email,
            COALESCE(v_first_name, 'Unknown'),
            COALESCE(v_last_name, 'User'),
            v_phone,
            v_delivery_group,
            CASE WHEN v_delivery_group IS NOT NULL THEN true ELSE false END,
            true
        );
        
        RAISE NOTICE 'Regular user profile created successfully';
        
    END IF;
    
    RETURN NEW;
EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'Record already exists for user: %', NEW.id;
        RETURN NEW;
    WHEN OTHERS THEN
        RAISE WARNING 'Error creating user/admin profile for %: %', NEW.id, SQLERRM;
        RAISE WARNING 'Error detail: %', SQLSTATE;
        RETURN NEW;
END;
$$;
