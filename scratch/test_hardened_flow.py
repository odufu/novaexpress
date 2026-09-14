import urllib.request
import json
import ssl

SUPABASE_URL = "https://qpcafevjsrbauweuiiyq.supabase.co"
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFwY2FmZXZqc3JiYXV3ZXVpaXlxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODc4NjM2NCwiZXhwIjoyMTA0MzYyMzY0fQ.RM1BJWKYWnhI7kkDVACqAxDj8U9shpWxQX8h8_K7UiU"

ctx = ssl.create_default_context()

def api_call(endpoint, method="GET", payload=None):
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(
        f"{SUPABASE_URL}{endpoint}",
        headers={
            "apikey": SERVICE_ROLE_KEY,
            "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
            "Content-Type": "application/json",
            "Prefer": "return=representation"
        },
        data=data,
        method=method
    )
    with urllib.request.urlopen(req, context=ctx) as resp:
        content = resp.read().decode()
        return resp.status, json.loads(content) if content else {}

WUSE_DC_ID = "22222222-2222-4222-8222-222222222222"
RESPIRA_SKU = "SKU-PRD-8573"

# 1. Product state before
st, p = api_call(f"/rest/v1/products?sku=eq.{RESPIRA_SKU}&select=id,name,stock_quantity,dc_stocks")
respira = p[0]
before_qty = respira["dc_stocks"].get(WUSE_DC_ID, 0)
print(f"Respira Wuse DC stock BEFORE test: {before_qty}")

# 2. Dispatch 7 units from Client to Wuse DC
disp_payload = {
    "p_client_id": "00000000-0000-4000-8000-789382731303",
    "p_dc_id": WUSE_DC_ID,
    "p_items": [{"product_id": respira["id"], "quantity": 7, "notes": "E2E verification test"}],
    "p_sender_id": "82525af2-6721-406d-ab21-e03150adaeb2",
    "p_sender_name": "Novacare Dispatcher",
    "p_notes": "Testing supply hardening"
}
st, disp_res = api_call("/rest/v1/rpc/fn_dispatch_client_supply", method="POST", payload=disp_payload)
print(f"Dispatch status: {st}, waybill: {disp_res.get('waybill_number')}")
trf_id = disp_res["transfer_id"]

# 3. Receive using hardened fn_receive_client_supply
# Note: quantity_received is passed as 0 with 0 damage/missing, verifying auto-fallback to quantity_shipped (7)
recv_payload = {
    "p_transfer_id": trf_id,
    "p_receiver_id": "88defe3b-3d7b-4616-a897-3e848caaecf1",
    "p_receiver_name": "Ahmed Bello",
    "p_receiver_signature_url": "",
    "p_verified_items": [
        {
            "item_id": "00000000-0000-0000-0000-000000000000", # intentionally mismatched item_id, testing product_id match
            "product_id": respira["id"],
            "quantity_received": 0, # testing fallback to shipped
            "quantity_damaged": 0,
            "quantity_missing": 0,
            "notes": "Verified in station"
        }
    ],
    "p_notes": "Hardened receive test"
}
st, recv_res = api_call("/rest/v1/rpc/fn_receive_client_supply", method="POST", payload=recv_payload)
print(f"Receive status: {st}, result: {recv_res}")

# 4. Check product stock after receive
st, p = api_call(f"/rest/v1/products?sku=eq.{RESPIRA_SKU}&select=id,name,stock_quantity,dc_stocks")
after_qty = p[0]["dc_stocks"].get(WUSE_DC_ID, 0)
print(f"Respira Wuse DC stock AFTER receive: {after_qty} (expected: {before_qty + 7})")
assert after_qty == before_qty + 7, f"FAILED: Expected {before_qty + 7}, got {after_qty}"

# 5. Check item quantity_received
st, items = api_call(f"/rest/v1/stock_transfer_items?transfer_id=eq.{trf_id}&select=*")
print(f"Transfer item row: {items[0]}")
assert items[0]["quantity_received"] == 7, f"FAILED: Expected quantity_received == 7, got {items[0]['quantity_received']}"

# 6. Test guard against excessive handover
st, rider = api_call("/rest/v1/delivery_agents?limit=1&select=id,user_id,full_name")
rider_id = rider[0]["id"]
issue_fail_payload = {
    "p_dc_id": WUSE_DC_ID,
    "p_rider_id": rider_id,
    "p_items": [{"product_id": respira["id"], "quantity": 9999}],
    "p_sender_id": "88defe3b-3d7b-4616-a897-3e848caaecf1",
    "p_sender_name": "Ahmed Bello",
    "p_notes": "Attempting excess handover"
}
st, fail_res = api_call("/rest/v1/rpc/fn_issue_dc_stock_to_rider", method="POST", payload=issue_fail_payload)
print(f"Excessive handover attempt: {fail_res}")
assert fail_res.get("success") == False, "FAILED: Excessive handover should have been blocked!"

# 7. Test valid handover and cancellation
issue_valid_payload = {
    "p_dc_id": WUSE_DC_ID,
    "p_rider_id": rider_id,
    "p_items": [{"product_id": respira["id"], "quantity": 5}],
    "p_sender_id": "88defe3b-3d7b-4616-a897-3e848caaecf1",
    "p_sender_name": "Ahmed Bello",
    "p_notes": "Test valid handover to cancel"
}
st, valid_issue_res = api_call("/rest/v1/rpc/fn_issue_dc_stock_to_rider", method="POST", payload=issue_valid_payload)
print(f"Valid handover dispatch: {valid_issue_res}")
trf_to_cancel = valid_issue_res["transfer_id"]

# Check stock debited by 5
st, p = api_call(f"/rest/v1/products?sku=eq.{RESPIRA_SKU}&select=id,name,stock_quantity,dc_stocks")
debited_qty = p[0]["dc_stocks"].get(WUSE_DC_ID, 0)
print(f"Stock after 5 issued: {debited_qty} (expected: {after_qty - 5})")
assert debited_qty == after_qty - 5

# Cancel handover and check restitution
st, cancel_res = api_call("/rest/v1/rpc/fn_cancel_dc_stock_handover", method="POST", payload={
    "p_transfer_id": trf_to_cancel,
    "p_cancelled_by": "88defe3b-3d7b-4616-a897-3e848caaecf1",
    "p_reason": "Testing cancellation restitution"
})
print(f"Cancellation result: {cancel_res}")
assert cancel_res.get("success") == True

# Check stock restored
st, p = api_call(f"/rest/v1/products?sku=eq.{RESPIRA_SKU}&select=id,name,stock_quantity,dc_stocks")
restored_qty = p[0]["dc_stocks"].get(WUSE_DC_ID, 0)
print(f"Stock after cancellation: {restored_qty} (expected: {after_qty})")
assert restored_qty == after_qty

print("\n🎉 ALL HARDENING & AUDIT VERIFICATION CHECKS PASSED PERFECTLY!")
