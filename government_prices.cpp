#include "government_prices.h"

#include <algorithm>
#include <cctype>
#include <optional>
#include <regex>
#include <string>
#include <utility>

#ifdef _WIN32
#include <windows.h>
#include <winhttp.h>
#else
#include <curl/curl.h>
#include <mutex>
#endif

namespace {

constexpr const char *FUEL_NEWS_URL =
    "https://www.gov.pl/web/energia/wiadomosci";
constexpr const char *ELECTRICITY_URL =
    "https://www.ure.gov.pl/pl/energia-elektryczna/ceny-wskazniki/7852,"
    "Srednia-cena-sprzedazy-energii-elektrycznej-na-rynku-konkurencyjnym-roczna-i-kwa.html";
constexpr const char *GAS_URL =
    "https://www.ure.gov.pl/pl/paliwa-gazowe/ceny-wskazniki/7859,"
    "Srednie-kwartalne-ceny-zakupu-gazu-ziemnego-sprowadzanego-z-panstw-czlonkowskich.html";

bool is_poland(const std::string &country)
{
    std::string value;
    value.reserve(country.size());
    for (unsigned char c : country)
        value += static_cast<char>(std::tolower(c));

    value.erase(0, value.find_first_not_of(" \t\r\n"));
    const std::size_t last = value.find_last_not_of(" \t\r\n");
    if (last != std::string::npos) value.erase(last + 1);

    return value == "pl" || value == "pol" || value == "poland" || value == "polska";
}

void replace_all(std::string &text, const std::string &from, const std::string &to)
{
    std::size_t pos = 0;
    while ((pos = text.find(from, pos)) != std::string::npos)
    {
        text.replace(pos, from.size(), to);
        pos += to.size();
    }
}

std::string trim(const std::string &text)
{
    const std::size_t first = text.find_first_not_of(" \t\r\n");
    if (first == std::string::npos) return "";
    const std::size_t last = text.find_last_not_of(" \t\r\n");
    return text.substr(first, last - first + 1);
}

std::string strip_tags(std::string html)
{
    replace_all(html, "&nbsp;", " ");
    replace_all(html, "&#160;", " ");
    replace_all(html, "&ndash;", "-");
    replace_all(html, "&#8211;", "-");
    replace_all(html, "&amp;", "&");

    const std::regex tag("<[^>]*>");
    html = std::regex_replace(html, tag, "");
    return trim(html);
}

std::optional<double> parse_decimal(const std::string &text)
{
    static const std::regex decimal(R"(([0-9]+[.,][0-9]{1,2}))");
    std::smatch match;
    if (!std::regex_search(text, match, decimal)) return std::nullopt;
    std::string normalized = match[1].str();
    std::replace(normalized.begin(), normalized.end(), ',', '.');
    try
    {
        return std::stod(normalized);
    }
    catch (...)
    {
        return std::nullopt;
    }
}

std::optional<double> price_after_label(const std::string &text, const std::string &label)
{
    std::string haystack;
    haystack.reserve(text.size());
    for (unsigned char c : text)
        haystack += static_cast<char>(std::tolower(c));

    std::string needle;
    needle.reserve(label.size());
    for (unsigned char c : label)
        needle += static_cast<char>(std::tolower(c));

    const std::size_t pos = haystack.find(needle);
    if (pos == std::string::npos) return std::nullopt;
    return parse_decimal(text.substr(pos + needle.size()));
}

#ifdef _WIN32
std::optional<std::string> http_get(const std::string &url)
{
    const std::wstring wide_url(url.begin(), url.end());
    URL_COMPONENTS parts = {};
    parts.dwStructSize = sizeof(parts);
    parts.dwSchemeLength = 1;
    parts.dwHostNameLength = 1;
    parts.dwUrlPathLength = 1;
    parts.dwExtraInfoLength = 1;
    if (!WinHttpCrackUrl(wide_url.c_str(), static_cast<DWORD>(wide_url.size()), 0, &parts))
        return std::nullopt;

    const std::wstring host(parts.lpszHostName, parts.dwHostNameLength);
    std::wstring path(parts.lpszUrlPath, parts.dwUrlPathLength);
    if (parts.dwExtraInfoLength > 0)
    {
        path += L'?';
        path.append(parts.lpszExtraInfo, parts.dwExtraInfoLength);
    }

    HINTERNET session = WinHttpOpen(L"CarCalc", WINHTTP_ACCESS_TYPE_DEFAULT_PROXY,
                                    WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, 0);
    if (!session) return std::nullopt;

    HINTERNET connection = WinHttpConnect(session, host.c_str(), parts.nPort, 0);
    if (!connection)
    {
        WinHttpCloseHandle(session);
        return std::nullopt;
    }

    const DWORD flags = parts.nScheme == INTERNET_SCHEME_HTTPS ? WINHTTP_FLAG_SECURE : 0;
    HINTERNET request = WinHttpOpenRequest(connection, L"GET", path.c_str(), nullptr,
                                           WINHTTP_NO_REFERER, WINHTTP_DEFAULT_ACCEPT_TYPES, flags);
    if (!request)
    {
        WinHttpCloseHandle(connection);
        WinHttpCloseHandle(session);
        return std::nullopt;
    }

    std::optional<std::string> result;
    if (WinHttpSendRequest(request, WINHTTP_NO_ADDITIONAL_HEADERS, 0,
                           WINHTTP_NO_REQUEST_DATA, 0, 0, 0) &&
        WinHttpReceiveResponse(request, nullptr))
    {
        DWORD status = 0;
        DWORD status_size = sizeof(status);
        if (WinHttpQueryHeaders(request,
                                WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER,
                                WINHTTP_HEADER_NAME_BY_INDEX, &status, &status_size,
                                WINHTTP_NO_HEADER_INDEX) &&
            status >= 200 && status < 300)
        {
            std::string body;
            char buffer[8192];
            DWORD read = 0;
            while (WinHttpReadData(request, buffer, sizeof(buffer), &read) && read > 0)
                body.append(buffer, read);
            result = std::move(body);
        }
    }

    WinHttpCloseHandle(request);
    WinHttpCloseHandle(connection);
    WinHttpCloseHandle(session);
    return result;
}
#else
std::size_t curl_write_cb(char *data, std::size_t size, std::size_t count, void *user_data)
{
    const std::size_t bytes = size * count;
    static_cast<std::string *>(user_data)->append(data, bytes);
    return bytes;
}

std::optional<std::string> http_get(const std::string &url)
{
    static std::once_flag curl_init;
    std::call_once(curl_init, []() { curl_global_init(CURL_GLOBAL_DEFAULT); });

    CURL *handle = curl_easy_init();
    if (!handle) return std::nullopt;

    std::string body;
    curl_easy_setopt(handle, CURLOPT_URL, url.c_str());
    curl_easy_setopt(handle, CURLOPT_FOLLOWLOCATION, 1L);
    curl_easy_setopt(handle, CURLOPT_WRITEFUNCTION, curl_write_cb);
    curl_easy_setopt(handle, CURLOPT_WRITEDATA, &body);
    curl_easy_setopt(handle, CURLOPT_USERAGENT, "CarCalc/1");
    curl_easy_setopt(handle, CURLOPT_TIMEOUT, 20L);
    curl_easy_setopt(handle, CURLOPT_NOSIGNAL, 1L);

    const CURLcode code = curl_easy_perform(handle);
    long status = 0;
    curl_easy_getinfo(handle, CURLINFO_RESPONSE_CODE, &status);
    curl_easy_cleanup(handle);

    if (code != CURLE_OK || status < 200 || status >= 300) return std::nullopt;
    return body;
}
#endif

std::optional<GovernmentFuelPrices> parse_fuel_page(const std::string &html)
{
    static const std::regex intro_re(R"(<div class="intro">([\s\S]*?)</div>)", std::regex::icase);
    static const std::regex link_re(R"re(<a[^>]*href="([^"]+)"[^>]*>([\s\S]*?)</a>)re", std::regex::icase);

    for (std::sregex_iterator it(html.begin(), html.end(), intro_re), end; it != end; ++it)
    {
        const std::string intro = strip_tags(it->str(1));
        if (intro.find("Benzyna 95") == std::string::npos) continue;

        const auto pb95 = price_after_label(intro, "Benzyna 95");
        const auto pb98 = price_after_label(intro, "Benzyna 98");
        const auto diesel = price_after_label(intro, "olej napędowy");
        if (!pb95 || !pb98 || !diesel) continue;

        GovernmentFuelPrices prices;
        prices.pb95_pln_per_l = *pb95;
        prices.pb98_pln_per_l = *pb98;
        prices.diesel_pln_per_l = *diesel;
        prices.source_url = FUEL_NEWS_URL;
        prices.effective_period = "latest published period";

        const std::string prefix = html.substr(0, static_cast<std::size_t>(it->position()));
        for (std::sregex_iterator link(prefix.begin(), prefix.end(), link_re), link_end;
             link != link_end; ++link)
        {
            const std::string title = strip_tags(link->str(2));
            if (title.find("Maksymalna cena detaliczna paliw") == std::string::npos) continue;

            const std::string href = link->str(1);
            prices.source_url = href.rfind("http", 0) == 0 ? href : std::string("https://www.gov.pl") + href;
            prices.effective_period = title;
        }
        return prices;
    }
    return std::nullopt;
}

struct UreReading
{
    double value = 0.0;
    int quarter = 0;
    std::string year;
};

std::optional<UreReading> parse_latest_ure_price(const std::string &html)
{
    static const std::regex row_re(
        R"(<tr[^>]*>\s*<td[^>]*>\s*(20[0-9]{2})\s*</td>([\s\S]*?)</tr>)",
        std::regex::icase);
    static const std::regex cell_re(R"(<td[^>]*>([\s\S]*?)</td>)", std::regex::icase);
    static const std::regex decimal(R"(([0-9]+[.,][0-9]{2}))");

    std::smatch row;
    if (!std::regex_search(html, row, row_re)) return std::nullopt;

    UreReading reading;
    reading.year = row[1].str();
    int quarter = 0;
    bool found = false;

    const auto cells_begin = row[2].first;
    const auto cells_end = row[2].second;
    for (std::sregex_iterator it(cells_begin, cells_end, cell_re), end; it != end; ++it)
    {
        const std::string text = strip_tags(it->str(1));
        std::smatch value;
        if (!std::regex_search(text, value, decimal)) continue;
        std::string normalized = value[1].str();
        std::replace(normalized.begin(), normalized.end(), ',', '.');
        try
        {
            reading.value = std::stod(normalized);
            reading.quarter = ++quarter;
            found = true;
        }
        catch (...)
        {
            // Ignore malformed cells and keep the last valid reading.
        }
    }
    if (!found) return std::nullopt;
    return reading;
}

} // namespace

std::optional<GovernmentFuelPrices> get_fuel_price_for_country(const std::string &country)
{
    if (!is_poland(country)) return std::nullopt;
    const auto html = http_get(FUEL_NEWS_URL);
    if (!html) return std::nullopt;
    return parse_fuel_page(*html);
}

std::optional<GovernmentPrices> get_government_prices_for_country(const std::string &country)
{
    if (!is_poland(country)) return std::nullopt;

    const auto fuel = get_fuel_price_for_country(country);
    const auto electricity_html = http_get(ELECTRICITY_URL);
    const auto gas_html = http_get(GAS_URL);
    if (!fuel || !electricity_html || !gas_html) return std::nullopt;

    const auto electricity = parse_latest_ure_price(*electricity_html);
    const auto gas = parse_latest_ure_price(*gas_html);
    if (!electricity || !gas) return std::nullopt;

    GovernmentPrices prices;
    prices.fuel = *fuel;
    prices.electricity_pln_per_mwh = electricity->value;
    prices.gas_pln_per_mwh = gas->value;
    prices.electricity_source_url = ELECTRICITY_URL;
    prices.gas_source_url = GAS_URL;
    prices.electricity_period = electricity->year + " Q" + std::to_string(electricity->quarter);
    prices.gas_period = gas->year + " Q" + std::to_string(gas->quarter);
    return prices;
}
