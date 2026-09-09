<?php
// SMS Gateway Configuration for Live Production Server
// Supported Providers: 'fast2sms', 'msg91', 'custom', 'none'

define('ENABLE_REAL_SMS', false); // Set to true when live server has an active SMS API key
define('SMS_GATEWAY_PROVIDER', 'fast2sms'); // 'fast2sms' or 'msg91'

// Fast2SMS Configuration (https://www.fast2sms.com)
define('FAST2SMS_API_KEY', 'YOUR_FAST2SMS_API_KEY_HERE');

// MSG91 Configuration (https://msg91.com)
define('MSG91_AUTH_KEY', 'YOUR_MSG91_AUTH_KEY_HERE');
define('MSG91_TEMPLATE_ID', 'YOUR_MSG91_DLT_TEMPLATE_ID_HERE');

/**
 * Send real SMS to student's mobile number via SMS Gateway API
 */
function send_real_sms_otp($phone, $otp) {
    if (!ENABLE_REAL_SMS) {
        return ['success' => false, 'message' => 'Real SMS gateway disabled (Local Mode)'];
    }

    // Clean phone number (strip non-digits)
    $clean_phone = preg_replace('/[^0-9]/', '', $phone);
    if (strlen($clean_phone) > 10) {
        $clean_phone = substr($clean_phone, -10);
    }

    if (SMS_GATEWAY_PROVIDER === 'fast2sms') {
        $apiKey = FAST2SMS_API_KEY;
        if (empty($apiKey) || $apiKey === 'YOUR_FAST2SMS_API_KEY_HERE') {
            return ['success' => false, 'message' => 'Fast2SMS API key not configured'];
        }

        $fields = array(
            "variables_values" => $otp,
            "route" => "otp",
            "numbers" => $clean_phone,
        );

        $curl = curl_init();
        curl_setopt_array($curl, array(
            CURLOPT_URL => "https://www.fast2sms.com/dev/bulkV2",
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_ENCODING => "",
            CURLOPT_MAXREDIRS => 10,
            CURLOPT_TIMEOUT => 15,
            CURLOPT_SSL_VERIFYPEER => false,
            CURLOPT_HTTP_VERSION => CURL_HTTP_VERSION_1_1,
            CURLOPT_CUSTOMREQUEST => "POST",
            CURLOPT_POSTFIELDS => json_encode($fields),
            CURLOPT_HTTPHEADER => array(
                "authorization: " . $apiKey,
                "accept: */*",
                "cache-control: no-cache",
                "content-type: application/json"
            ),
        ));

        $response = curl_exec($curl);
        $err = curl_error($curl);
        curl_close($curl);

        if ($err) {
            return ['success' => false, 'message' => 'SMS Gateway Error: ' . $err];
        }
        $resData = json_decode($response, true);
        return ['success' => isset($resData['return']) && $resData['return'] === true, 'raw' => $response];

    } elseif (SMS_GATEWAY_PROVIDER === 'msg91') {
        $authKey = MSG91_AUTH_KEY;
        $templateId = MSG91_TEMPLATE_ID;
        if (empty($authKey) || $authKey === 'YOUR_MSG91_AUTH_KEY_HERE') {
            return ['success' => false, 'message' => 'MSG91 Auth key not configured'];
        }

        $curl = curl_init();
        $url = "https://control.msg91.com/api/v5/otp?template_id=" . urlencode($templateId) . "&mobile=91" . $clean_phone . "&otp=" . urlencode($otp);
        curl_setopt_array($curl, array(
            CURLOPT_URL => $url,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_CUSTOMREQUEST => "GET",
            CURLOPT_HTTPHEADER => array(
                "authkey: " . $authKey
            ),
        ));

        $response = curl_exec($curl);
        $err = curl_error($curl);
        curl_close($curl);

        if ($err) {
            return ['success' => false, 'message' => 'MSG91 Error: ' . $err];
        }
        $resData = json_decode($response, true);
        return ['success' => isset($resData['type']) && $resData['type'] === 'success', 'raw' => $response];
    }

    return ['success' => false, 'message' => 'No valid SMS provider configured'];
}
