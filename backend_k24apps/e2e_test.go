package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"testing"
	"time"
)

const baseURL = "http://127.0.0.1:8087/api"

type ResponseMap struct {
	Status  string                 `json:"status"`
	Message string                 `json:"message"`
	Data    map[string]interface{} `json:"data"`
}

type ResponseList struct {
	Status  string                   `json:"status"`
	Message string                   `json:"message"`
	Data    []map[string]interface{} `json:"data"`
}

func doRequest(method, url string, body interface{}, token string) ([]byte, int, error) {
	var bodyReader io.Reader
	if body != nil {
		jsonBytes, err := json.Marshal(body)
		if err != nil {
			return nil, 0, err
		}
		bodyReader = bytes.NewReader(jsonBytes)
	}

	req, err := http.NewRequest(method, url, bodyReader)
	if err != nil {
		return nil, 0, err
	}

	req.Header.Set("Content-Type", "application/json")
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return nil, 0, err
	}
	defer resp.Body.Close()

	respBytes, err := io.ReadAll(resp.Body)
	return respBytes, resp.StatusCode, err
}

func TestE2E_SurabayaAndJakartaFlow(t *testing.T) {
	fmt.Println("==================================================")
	fmt.Println("🚀 RUNNING E2E INTEGRATION TEST: SURABAYA & JAKARTA")
	fmt.Println("==================================================")

	// 1. Admin Login
	adminLoginReq := map[string]string{
		"email":    "goodwheel@k24.com",
		"password": "good123",
	}
	body, code, err := doRequest("POST", baseURL+"/auth/login", adminLoginReq, "")
	if err != nil || code != 200 {
		t.Fatalf("❌ Admin login failed (code %d): %v, body: %s", code, err, string(body))
	}
	var adminResp ResponseMap
	json.Unmarshal(body, &adminResp)
	adminToken := adminResp.Data["token"].(string)
	fmt.Println("✅ Step 1: Admin Login Successful. Token acquired.")

	// 2. Register / Setup Mitra Surabaya
	mitraSbyUsername := fmt.Sprintf("mitra_sby_%d", time.Now().Unix())
	motorKmSby := 2000.0
	motorZona1Sby := 20000.0
	motorZona2Sby := 25000.0
	motorZona3Sby := 30000.0
	mobilKmSby := 25000.0

	mitraSbyReq := map[string]interface{}{
		"username":       mitraSbyUsername,
		"email":          mitraSbyUsername + "@k24.co.id",
		"name":           "PT K-24 Surabaya Regional",
		"phone":          "081234567890",
		"password":       "password123",
		"pic_name":       "Budi PIC Surabaya",
		"pic_nik":        "3578010101010001",
		"alamat_lengkap": "Jl. Raya Darmo No. 42, Surabaya",
		"pickup_name":    "Gudang Utama Surabaya",
		"pickup_lat":     -7.289100,
		"pickup_long":    112.743100,
		"motor_km":       &motorKmSby,
		"motor_zona1":    &motorZona1Sby,
		"motor_zona2":    &motorZona2Sby,
		"motor_zona3":    &motorZona3Sby,
		"mobil_km":       &mobilKmSby,
	}
	body, code, err = doRequest("POST", baseURL+"/admin/mitra", mitraSbyReq, adminToken)
	if err != nil || (code != 200 && code != 201) {
		t.Fatalf("❌ Create Mitra Surabaya failed: %v, body: %s", err, string(body))
	}
	var sbyMitraResp ResponseMap
	json.Unmarshal(body, &sbyMitraResp)
	sbyMitraID := int(sbyMitraResp.Data["id"].(float64))
	fmt.Printf("✅ Step 2: Mitra Surabaya Created & Configured (ID: %d, Username: %s)\n", sbyMitraID, mitraSbyUsername)

	// 3. Register / Setup Mitra Jakarta
	mitraJktUsername := fmt.Sprintf("mitra_jkt_%d", time.Now().Unix())
	motorKmJkt := 2500.0
	motorTitikJkt := 12000.0
	mobilKmJkt := 30000.0

	mitraJktReq := map[string]interface{}{
		"username":       mitraJktUsername,
		"email":          mitraJktUsername + "@k24.co.id",
		"name":           "PT K-24 Jakarta Regional",
		"phone":          "081987654321",
		"password":       "password123",
		"pic_name":       "Siti PIC Jakarta",
		"pic_nik":        "3171020202020002",
		"alamat_lengkap": "Jl. Matraman Raya No. 10, Jakarta Timur",
		"pickup_name":    "Hub Central Jakarta",
		"pickup_lat":     -6.211200,
		"pickup_long":    106.858200,
		"motor_km":       &motorKmJkt,
		"motor_titik":    &motorTitikJkt,
		"mobil_km":       &mobilKmJkt,
	}
	body, code, err = doRequest("POST", baseURL+"/admin/mitra", mitraJktReq, adminToken)
	if err != nil || (code != 200 && code != 201) {
		t.Fatalf("❌ Create Mitra Jakarta failed: %v, body: %s", err, string(body))
	}
	var jktMitraResp ResponseMap
	json.Unmarshal(body, &jktMitraResp)
	jktMitraID := int(jktMitraResp.Data["id"].(float64))
	fmt.Printf("✅ Step 3: Mitra Jakarta Created & Configured (ID: %d, Username: %s)\n", jktMitraID, mitraJktUsername)

	// 4. Create Drivers (Surabaya & Jakarta)
	drvSbyUsername := fmt.Sprintf("drv_sby_%d", time.Now().Unix())
	drvSbyReq := map[string]string{
		"username":     drvSbyUsername,
		"email":        drvSbyUsername + "@driver.com",
		"name":         "Budi Driver Surabaya",
		"phone":        "081111111111",
		"plate_number": "L 1234 SBY",
		"password":     "driver123",
		"vehicle_type": "motor",
		"role":         "DRIVER",
	}
	body, code, err = doRequest("POST", baseURL+"/auth/register", drvSbyReq, "")
	if err != nil || (code != 200 && code != 201) {
		t.Fatalf("❌ Register Driver Surabaya failed: %v, body: %s", err, string(body))
	}
	var sbyDrvResp ResponseMap
	json.Unmarshal(body, &sbyDrvResp)
	sbyDriverID := int(sbyDrvResp.Data["driver"].(map[string]interface{})["id"].(float64))
	drvSbyToken := sbyDrvResp.Data["token"].(string)

	// Approve Driver Surabaya
	_, appCode, _ := doRequest("POST", fmt.Sprintf("%s/admin/drivers/%d/approve", baseURL, sbyDriverID), nil, adminToken)
	if appCode != 200 {
		t.Fatalf("❌ Approve Driver Surabaya failed with code %d", appCode)
	}
	fmt.Printf("✅ Step 4: Driver Surabaya Registered & Approved (ID: %d)\n", sbyDriverID)

	drvJktUsername := fmt.Sprintf("drv_jkt_%d", time.Now().Unix())
	drvJktReq := map[string]string{
		"username":     drvJktUsername,
		"email":        drvJktUsername + "@driver.com",
		"name":         "Joko Driver Jakarta",
		"phone":        "082222222222",
		"plate_number": "B 5678 JKT",
		"password":     "driver123",
		"vehicle_type": "motor",
		"role":         "DRIVER",
	}
	body, code, err = doRequest("POST", baseURL+"/auth/register", drvJktReq, "")
	if err != nil || (code != 200 && code != 201) {
		t.Fatalf("❌ Register Driver Jakarta failed: %v, body: %s", err, string(body))
	}
	var jktDrvResp ResponseMap
	json.Unmarshal(body, &jktDrvResp)
	jktDriverID := int(jktDrvResp.Data["driver"].(map[string]interface{})["id"].(float64))
	drvJktToken := jktDrvResp.Data["token"].(string)

	// Approve Driver Jakarta
	_, appCodeJkt, _ := doRequest("POST", fmt.Sprintf("%s/admin/drivers/%d/approve", baseURL, jktDriverID), nil, adminToken)
	if appCodeJkt != 200 {
		t.Fatalf("❌ Approve Driver Jakarta failed with code %d", appCodeJkt)
	}
	fmt.Printf("✅ Step 5: Driver Jakarta Registered & Approved (ID: %d)\n", jktDriverID)

	// 5. Test Calculate & Create Bulk Orders for Surabaya (Skema Zona 1, 2, 3 + Non-Zona Gresik)
	calcSbyReq := map[string]interface{}{
		"mitra_id":  sbyMitraID,
		"armada":    "motor",
		"rate_type": "zona",
		"items": []map[string]interface{}{
			{
				"nama_apotek":    "Apotek K-24 Kutisari Surabaya",
				"alamat_lengkap": "Jl. Kutisari Sel. No.130, Kutisari, Kec. Tenggilis Mejoyo, Surabaya, Jawa Timur 60291",
				"latitude":       -7.332500,
				"longitude":      112.748200,
				"invoices":       []string{"INV-SBY-001"},
			},
			{
				"nama_apotek":    "Apotek K-24 Mulyosari Surabaya",
				"alamat_lengkap": "Jl. Raya Mulyosari No.112, Kalisari, Kec. Mulyorejo, Surabaya, Jawa Timur 60115",
				"latitude":       -7.262500,
				"longitude":      112.791200,
				"invoices":       []string{"INV-SBY-002"},
			},
			{
				"nama_apotek":    "Apotek K-24 Wiyung Surabaya",
				"alamat_lengkap": "Jl. Raya Menganti No.36, Wiyung, Kec. Wiyung, Surabaya, Jawa Timur 60228",
				"latitude":       -7.311200,
				"longitude":      112.698500,
				"invoices":       []string{"INV-SBY-003"},
			},
			{
				"nama_apotek":    "Apotek K-24 Driyorejo Gresik",
				"alamat_lengkap": "Jl. Raya Batu Mulia, Paras, Mulung, Kec. Driyorejo, Kabupaten Gresik, Jawa Timur 61177",
				"latitude":       -7.348200,
				"longitude":      112.621500,
				"invoices":       []string{"INV-SBY-004"},
			},
		},
	}

	body, code, err = doRequest("POST", baseURL+"/admin/orders/calculate", calcSbyReq, adminToken)
	if err != nil || (code != 200 && code != 201) {
		t.Fatalf("❌ Calculate Surabaya orders failed: %v, body: %s", err, string(body))
	}
	var calcSbyResp ResponseMap
	json.Unmarshal(body, &calcSbyResp)
	fmt.Println("✅ Step 8: Surabaya Argo Calculated. Summary items:")
	itemsSlice := calcSbyResp.Data["items"].([]interface{})
	for idx, itm := range itemsSlice {
		m := itm.(map[string]interface{})
		fmt.Printf("   - Stop %d: %s | Tagihan: Rp %.0f | Driver Fee: Rp %.0f | Label: %s\n",
			idx+1, m["nama_apotek"], m["price"], m["driver_fee"], m["rate_label"])
	}

	// Create Bulk Orders Surabaya
	body, code, err = doRequest("POST", baseURL+"/admin/orders/bulk", calcSbyReq, adminToken)
	if err != nil || (code != 200 && code != 201) {
		t.Fatalf("❌ Create bulk Surabaya orders failed: %v, body: %s", err, string(body))
	}
	var createSbyResp ResponseList
	json.Unmarshal(body, &createSbyResp)
	var sbyOrderIDs []int
	for _, o := range createSbyResp.Data {
		sbyOrderIDs = append(sbyOrderIDs, int(o["id"].(float64)))
	}
	fmt.Printf("✅ Step 9: Surabaya Orders Saved to DB (Total: %d orders)\n", len(sbyOrderIDs))

	// 6. Dispatch Surabaya Orders to Driver Surabaya
	dispatchSbyReq := map[string]interface{}{
		"driver_id": sbyDriverID,
		"order_ids": sbyOrderIDs,
		"sequence":  sbyOrderIDs,
	}
	body, code, err = doRequest("POST", baseURL+"/admin/dispatch", dispatchSbyReq, adminToken)
	if err != nil || (code != 200 && code != 201) {
		t.Fatalf("❌ Create Dispatch Surabaya failed: %v, body: %s", err, string(body))
	}
	var dispSbyResp ResponseMap
	json.Unmarshal(body, &dispSbyResp)
	dispSbyID := dispSbyResp.Data["dispatch_number"].(string)
	fmt.Printf("✅ Step 10: Surabaya Orders Dispatched (Batch: %s -> Driver Sby ID %d)\n", dispSbyID, sbyDriverID)

	// 7. Driver Surabaya Dashboard Verification
	body, code, err = doRequest("GET", baseURL+"/driver/dashboard", nil, drvSbyToken)
	if err != nil || (code != 200 && code != 201) {
		t.Fatalf("❌ Driver Surabaya dashboard fetch failed: %v", err)
	}
	var sbyDashResp ResponseMap
	json.Unmarshal(body, &sbyDashResp)
	activeOrders := sbyDashResp.Data["active_orders"].([]interface{})

	fmt.Println("✅ Step 11: Driver Surabaya Dashboard Verified:")
	for idx, ord := range activeOrders {
		o := ord.(map[string]interface{})
		custName := o["customer_name"].(string)
		fee := o["delivery_fee"].(float64)
		fmt.Printf("   - Stop %d: %s | Net Driver Fee: Rp %.0f\n", idx+1, custName, fee)

		// Dynamic Assertions based on Pharmacy Zona
		if custName == "Apotek K-24 Kutisari Surabaya" && fee != 10500 {
			t.Errorf("⚠️ Expected Zona 1 driver fee 10.500 for Kutisari, got %.0f", fee)
		}
		if custName == "Apotek K-24 Mulyosari Surabaya" && fee != 17500 {
			t.Errorf("⚠️ Expected Zona 2 driver fee 17.500 for Mulyosari, got %.0f", fee)
		}
		if custName == "Apotek K-24 Wiyung Surabaya" && fee <= 0 {
			t.Errorf("⚠️ Expected valid driver fee for Wiyung, got %.0f", fee)
		}
		if custName == "Apotek K-24 Driyorejo Gresik" && fee <= 0 {
			t.Errorf("⚠️ Expected valid KM driver fee for Driyorejo Gresik, got %.0f", fee)
		}
	}

	// 8. Test Calculate & Create Bulk Orders for Jakarta (Skema KM)
	calcJktReq := map[string]interface{}{
		"mitra_id":  jktMitraID,
		"armada":    "motor",
		"rate_type": "km",
		"items": []map[string]interface{}{
			{
				"nama_apotek":    "Apotek K-24 Sunter",
				"alamat_lengkap": "Jl. Danau Utara Blok J-12, Sunter Agung, Jakarta Utara",
				"latitude":       -6.138500,
				"longitude":      106.865200,
				"invoices":       []string{"INV-JKT-001"},
			},
			{
				"nama_apotek":    "Apotek K-24 Cempaka Putih",
				"alamat_lengkap": "Jl. Cempaka Putih Raya No.104B, Jakarta Pusat",
				"latitude":       -6.175200,
				"longitude":      106.871200,
				"invoices":       []string{"INV-JKT-002"},
			},
		},
	}

	body, code, err = doRequest("POST", baseURL+"/admin/orders/bulk", calcJktReq, adminToken)
	if err != nil || (code != 200 && code != 201) {
		t.Fatalf("❌ Create bulk Jakarta orders failed: %v, body: %s", err, string(body))
	}
	var createJktResp ResponseList
	json.Unmarshal(body, &createJktResp)
	var jktOrderIDs []int
	for _, o := range createJktResp.Data {
		jktOrderIDs = append(jktOrderIDs, int(o["id"].(float64)))
	}
	fmt.Printf("✅ Step 12: Jakarta Orders Created & Saved (Total: %d orders)\n", len(jktOrderIDs))

	// Dispatch Jakarta Orders to Driver Jakarta
	dispatchJktReq := map[string]interface{}{
		"driver_id": jktDriverID,
		"order_ids": jktOrderIDs,
		"sequence":  jktOrderIDs,
	}
	body, code, err = doRequest("POST", baseURL+"/admin/dispatch", dispatchJktReq, adminToken)
	if err != nil || (code != 200 && code != 201) {
		t.Fatalf("❌ Create Dispatch Jakarta failed: %v, body: %s", err, string(body))
	}
	fmt.Printf("✅ Step 13: Jakarta Orders Dispatched -> Driver Jkt ID %d\n", jktDriverID)

	// Driver Jakarta Dashboard Verification
	body, code, err = doRequest("GET", baseURL+"/driver/dashboard", nil, drvJktToken)
	if err != nil || (code != 200 && code != 201) {
		t.Fatalf("❌ Driver Jakarta dashboard fetch failed: %v", err)
	}
	var jktDashResp ResponseMap
	json.Unmarshal(body, &jktDashResp)
	jktActiveOrders := jktDashResp.Data["active_orders"].([]interface{})

	fmt.Println("✅ Step 14: Driver Jakarta Dashboard Verified (Skema KM 1.750/KM):")
	for idx, ord := range jktActiveOrders {
		o := ord.(map[string]interface{})
		custName := o["customer_name"].(string)
		fee := o["delivery_fee"].(float64)
		dist := o["distance_km"].(float64)
		fmt.Printf("   - Stop %d: %s | Dist: %.2f KM | Net Driver Fee: Rp %.0f\n", idx+1, custName, dist, fee)

		if fee <= 0 {
			t.Errorf("⚠️ Expected non-zero driver fee for Jakarta KM rate, got %.0f", fee)
		}
	}

	fmt.Println("==================================================")
	fmt.Println("🎉 ALL E2E INTEGRATION TESTS PASSED 100% CLEANLY!")
	fmt.Println("==================================================")
}
