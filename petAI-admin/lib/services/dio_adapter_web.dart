import "package:dio/dio.dart";
import "package:dio/browser.dart";

void configureDioAdapter(Dio dio) {
  dio.httpClientAdapter = BrowserHttpClientAdapter(withCredentials: true);
}
