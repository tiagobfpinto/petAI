# petAI Admin Panel

Flutter admin app for managing petAI users (view users, adjust coins, grant chests).

## Running

1. Start the backend server (`petAI-backend`) so the admin API is reachable.
2. Ensure you have an admin account in the `admin_users` table.
3. From this directory:

```
flutter run
```

To point at a different backend URL:

```
flutter run --dart-define=PETAI_API=http://localhost:5000
```

## Notes

- Admin auth uses the existing `/admin/login` session cookie.
- The admin UI calls `/admin/api/users`, `/admin/api/users/<id>/coins`, and
  `/admin/api/users/<id>/chests`.
