import 'package:apidash/consts.dart';
import 'package:apidash/models/models.dart';
import 'package:apidash/utils/utils.dart' show getValidRequestUri;
import 'package:jinja/jinja.dart' as jj;

class SwiftURLSessionCodeGen {
  final String kTemplateStart = """
import Foundation

func sendRequest(completion: @escaping (Result<String, Error>) -> Void) {
    guard let url = URL(string: "{{url}}") else {
        completion(.failure(NSError(domain: "Invalid URL", code: 0, userInfo: nil)))
        return
    }

""";

  final String kTemplateQueryParams = """
    var urlComponents = URLComponents(string: "{{url}}")!
    var queryItems = [URLQueryItem]()
    {% for key, value in params %}
    queryItems.append(URLQueryItem(name: "{{key}}", value: "{{value}}"))
    {% endfor %}
    urlComponents.queryItems = queryItems

// """;

//   final String kTemplateURL = """
//     let url = urlComponents.url!

// """;

  final String kTemplateRequest = """
    var request = URLRequest(url: url)
    request.httpMethod = "{{method}}"

""";

  final String kTemplateHeaders = """
    {% for header, value in headers %}
    request.addValue("{{value}}", forHTTPHeaderField: "{{header}}")
    {% endfor %}

""";

  final String kTemplateBody = '''
    request.httpBody = """
    {{body}}
    """.data(using: .utf8)

''';

  final String kTemplateEnd = """

    let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
        if let error = error {
            completion(.failure(error))
            return
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            completion(.failure(NSError(domain: "Invalid response", code: 0, userInfo: nil)))
            return
        }

        print("Status Code: \\(httpResponse.statusCode)")

        if let data = data, let responseString = String(data: data, encoding: .utf8) {
            completion(.success(responseString))
        } else {
            completion(.failure(NSError(domain: "No data", code: 0, userInfo: nil)))
        }
    }

    task.resume()
}

sendRequest { result in
    switch result {
    case .success(let responseString):
        print("Response body: \\(responseString)")
    case .failure(let error):
        print("Error: \\(error)")
    }
}
""";

  String? getCode(HttpRequestModel requestModel) {
    try {
      String result = "";

      String url = requestModel.url;

      var templateStart = jj.Template(kTemplateStart);
      result += templateStart.render({"url": url});

      var rec = getValidRequestUri(url, requestModel.enabledParams);
      Uri? uri = rec.$1;

      if (uri != null) {
        if (uri.hasQuery) {
          var params = uri.queryParameters;
          if (params.isNotEmpty) {
            var templateQueryParam = jj.Template(kTemplateQueryParams);
            result += templateQueryParam.render({"params": params});
          }
        }

        var method = requestModel.method.name.toUpperCase();
        var templateRequest = jj.Template(kTemplateRequest);
        result += templateRequest.render({"method": method});

        var headersList = requestModel.enabledHeaders;
        if (headersList != null || requestModel.hasBody) {
          var headers = requestModel.enabledHeadersMap;
          if (requestModel.hasJsonData || requestModel.hasTextData) {
            headers.putIfAbsent(
                kHeaderContentType, () => requestModel.bodyContentType.header);
          }
          if (headers.isNotEmpty) {
            var templateHeader = jj.Template(kTemplateHeaders);
            result += templateHeader.render({"headers": headers});
          }
        }

        if (requestModel.hasTextData || requestModel.hasJsonData) {
          var templateBody = jj.Template(kTemplateBody);
          result += templateBody.render({"body": requestModel.body});
        }

        result += kTemplateEnd;
      }

      return result;
    } catch (e) {
      return null;
    }
  }
}
