namespace BanHang.WebAPI;

/// <summary>
/// Nạp file <c>.env</c> (tìm từ thư mục hiện tại ngược lên) vào biến môi trường khi chạy <c>dotnet run</c> local, để dùng
/// chung một file <c>.env</c> với docker compose. Biến đã có sẵn trong môi trường luôn được ưu tiên; không có file thì bỏ qua.
/// </summary>
public static class DotEnv
{
    public static void Load()
    {
        var dir = new DirectoryInfo(Directory.GetCurrentDirectory());
        while (dir is not null)
        {
            var path = Path.Combine(dir.FullName, ".env");
            if (File.Exists(path))
            {
                Apply(File.ReadAllLines(path));
                return;
            }

            dir = dir.Parent;
        }
    }

    private static void Apply(IEnumerable<string> lines)
    {
        foreach (var raw in lines)
        {
            var line = raw.Trim();
            if (line.Length == 0 || line.StartsWith('#'))
            {
                continue;
            }

            var separator = line.IndexOf('=');
            if (separator <= 0)
            {
                continue;
            }

            var key = line[..separator].Trim();
            var value = line[(separator + 1)..].Trim();
            if (value.Length >= 2 && (value[0] == '"' && value[^1] == '"' || value[0] == '\'' && value[^1] == '\''))
            {
                value = value[1..^1];
            }

            if (Environment.GetEnvironmentVariable(key) is null)
            {
                Environment.SetEnvironmentVariable(key, value);
            }
        }
    }
}
