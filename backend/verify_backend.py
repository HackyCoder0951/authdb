import requests
import time

BASE_URL = "http://localhost:8001/api/v1"

def test_backend():
    print("Starting Backend Verification...")

    # Unique email for every run
    timestamp = int(time.time())
    admin_email = f"admin_{timestamp}@example.com"
    user_email = f"user_{timestamp}@example.com"
    password = "password123"

    # 1. Register Admin
    print(f"1. Registering Admin ({admin_email})...")
    res = requests.post(f"{BASE_URL}/auth/register", json={
        "email": admin_email,
        "password": password,
        "role": "ADMIN"
    })
    if res.status_code != 201:
        print(f"Failed to register admin: {res.text}")
        return
    print("   Success")

    # 2. Register Regular User
    print(f"2. Registering User ({user_email})...")
    res = requests.post(f"{BASE_URL}/auth/register", json={
        "email": user_email,
        "password": password,
        "role": "USER"
    })
    if res.status_code != 201:
        print(f"Failed to register user: {res.text}")
        return
    print("   Success")

    # 3. Login Admin
    print("3. Logging in Admin...")
    res = requests.post(f"{BASE_URL}/auth/login", data={
        "username": admin_email,
        "password": password
    })
    if res.status_code != 200:
        print(f"Failed to login admin: {res.text}")
        return
    admin_token = res.json()["access_token"]
    print("   Success")

    # 4. Login User
    print("4. Logging in User...")
    res = requests.post(f"{BASE_URL}/auth/login", data={
        "username": user_email,
        "password": password
    })
    if res.status_code != 200:
        print(f"Failed to login user: {res.text}")
        return
    user_token = res.json()["access_token"]
    print("   Success")

    # Headers
    admin_headers = {"Authorization": f"Bearer {admin_token}"}
    user_headers = {"Authorization": f"Bearer {user_token}"}

    # 5. User Create Task
    print("5. User Creating Task...")
    res = requests.post(f"{BASE_URL}/tasks/", headers=user_headers, json={
        "title": "User Task",
        "description": "This is a task"
    })
    if res.status_code != 201:
        print(f"Failed to create task: {res.text}")
        return
    task_id = res.json()["_id"]
    print("   Success")

    # 6. User Read Tasks
    print("6. User Reading Tasks...")
    res = requests.get(f"{BASE_URL}/tasks/", headers=user_headers)
    if res.status_code != 200 or len(res.json()) == 0:
        print(f"Failed to read tasks: {res.text}")
        return
    print("   Success")

    # 7. Admin Read Tasks (RBAC Check)
    # Admin viewing generic lists might not see everyone's task unless using /all endpoint
    # Let's check the /all endpoint
    print("7. Admin Reading All Tasks...")
    res = requests.get(f"{BASE_URL}/tasks/all", headers=admin_headers)
    if res.status_code != 200:
        print(f"Failed to read all tasks as admin: {res.text}")
        return
    # Check if task_id is in the list
    all_tasks = res.json()
    if not any(t["_id"] == task_id for t in all_tasks):
         print("   Admin did not see the user task!")
         return
    print("   Success")

    # 8. Admin Delete Task
    print("8. Admin Deleting User Task...")
    res = requests.delete(f"{BASE_URL}/tasks/{task_id}", headers=admin_headers)
    if res.status_code != 200:
        print(f"Failed to delete task: {res.text}")
        return
    print("   Success")

    print("\nVerification Complete!")

if __name__ == "__main__":
    try:
        test_backend()
    except Exception as e:
        print(f"An error occurred: {e}")
