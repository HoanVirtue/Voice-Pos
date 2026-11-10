namespace BanHang.BuildingBlocks.Web;

/// <summary>
/// Uniform envelope every module returns from its handlers/controllers, so the WebApi host never
/// has to special-case one module's response shape versus another's.
/// </summary>
public class ActionResponse
{
    public bool Success { get; private set; } = true;
    public List<string> Errors { get; } = [];

    public static ActionResponse Ok() => new();

    public static ActionResponse Failed(string error) => new ActionResponse().AddError(error);

    public ActionResponse AddError(string error)
    {
        Success = false;
        Errors.Add(error);
        return this;
    }
}

public sealed class ActionResponse<T> : ActionResponse
{
    public T? Result { get; private set; }

    public static ActionResponse<T> Ok(T result)
    {
        var response = new ActionResponse<T>();
        response.SetResult(result);
        return response;
    }

    public static new ActionResponse<T> Failed(string error)
    {
        var response = new ActionResponse<T>();
        response.AddError(error);
        return response;
    }

    public ActionResponse<T> SetResult(T result)
    {
        Result = result;
        return this;
    }
}
