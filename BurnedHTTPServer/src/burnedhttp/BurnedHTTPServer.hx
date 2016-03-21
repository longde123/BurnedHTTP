package burnedhttp;
import burnedhttp.classes.ServerSettings;
import burnedhttp.HTTPResponse;
import burnedhttp.classes.Logger;
import haxe.io.Bytes;
import haxe.io.Eof;
import haxe.io.Path;
import hscript.*;
import sys.db.Types.SString;
import sys.FileSystem;
import sys.io.File;
import sys.net.Host;

/**
 * ...
 * @author omnibean
 */
class BurnedHTTPServer extends BaseHTTPServer
{
	public function new(serverSettings:ServerSettings)
	{
		super(serverSettings);
		Logger.WriteLine("Initialized FireHTTPServer listening on "+_hostAddress+":"+_port+" with web root "+ _wwwroot);
	}
	
	//{ MIME type mappings
	private static var _mimeTypeMappings:Map<String, String> = [
		".asf"=> "video/x-ms-asf",
		".asx"=> "video/x-ms-asf",
		".avi"=> "video/x-msvideo",
		".bin"=> "application/octet-stream",
		".cco"=> "application/x-cocoa",
		".crt"=> "application/x-x509-ca-cert",
		".css"=> "text/css",
		".deb"=> "application/octet-stream",
		".der"=> "application/x-x509-ca-cert",
		".dll"=> "application/octet-stream",
		".dmg"=> "application/octet-stream",
		".ear"=> "application/java-archive",
		".eot"=> "application/octet-stream",
		".exe"=> "application/octet-stream",
		".flv"=> "video/x-flv",
		".gif"=> "image/gif",
		".hqx"=> "application/mac-binhex40",
		".htc"=> "text/x-component",
		".htm"=> "text/html",
		".html"=> "text/html",
		".ico"=> "image/x-icon",
		".img"=> "application/octet-stream",
		".iso"=> "application/octet-stream",
		".jar"=> "application/java-archive",
		".jardiff"=> "application/x-java-archive-diff",
		".jng"=> "image/x-jng",
		".jnlp"=> "application/x-java-jnlp-file",
		".jpeg"=> "image/jpeg",
		".jpg"=> "image/jpeg",
		".js"=> "application/x-javascript",
		".mml"=> "text/mathml",
		".mng"=> "video/x-mng",
		".mov"=> "video/quicktime",
		".mp3"=> "audio/mpeg",
		".mpeg"=> "video/mpeg",
		".mpg"=> "video/mpeg",
		".msi"=> "application/octet-stream",
		".msm"=> "application/octet-stream",
		".msp"=> "application/octet-stream",
		".pdb"=> "application/x-pilot",
		".pdf"=> "application/pdf",
		".pem"=> "application/x-x509-ca-cert",
		".pl"=> "application/x-perl",
		".pm"=> "application/x-perl",
		".png"=> "image/png",
		".prc"=> "application/x-pilot",
		".ra"=> "audio/x-realaudio",
		".rar"=> "application/x-rar-compressed",
		".rpm"=> "application/x-redhat-package-manager",
		".rss"=> "text/xml",
		".run"=> "application/x-makeself",
		".sea"=> "application/x-sea",
		".shtml"=> "text/html",
		".sit"=> "application/x-stuffit",
		".swf"=> "application/x-shockwave-flash",
		".tcl"=> "application/x-tcl",
		".tk"=> "application/x-tcl",
		".txt"=> "text/plain",
		".war"=> "application/java-archive",
		".wbmp"=> "image/vnd.wap.wbmp",
		".wmv"=> "video/x-ms-wmv",
		".xap"=> "application/x-silverlight-app",
		".xaml"=> "application/xaml+xml",
		".xbap"=> "application/x-ms-xbap",
		".xml"=> "text/xml",
		".xpi"=> "application/x-xpinstall",
		".zip"=> "application/zip",
		//Custom Handlers
		".esc" => "text/html",
		//}
    ];
	
	private var executableFileTypes:Array<String> = [".hxc"];
	
	public function SendBytesWithMIMEType(path:String, response:HTTPResponse)
	{
		var extension:String = path.substring(path.lastIndexOf(".")).toLowerCase();
		var mimeType:String = "application/octet-stream";
		if (_mimeTypeMappings.exists(extension))
		{
			mimeType = _mimeTypeMappings[extension];
		}			
		var actualFilePath = FileSystem.absolutePath(_wwwroot + path);
		var fileExists:Bool = FileSystem.exists(actualFilePath) && !FileSystem.isDirectory(actualFilePath);
		if (!fileExists)
		{
			if (StringTools.endsWith(actualFilePath, "/index.html"))
			{
				sendStringToClient(response, GenerateDirectoryIndex(response, actualFilePath));
				return;
			}
			else
			{
				Logger.WriteLine("404!");
				response.sendError404();
				return;
			}
		}
		var executableFile:Bool = executableFileTypes.indexOf(extension) != -1;
		if (!executableFile)
		{
			response.sendHeader("HTTP/1.1 200 OK");
			response.sendHeader("Content-Type: "+mimeType);
			response.sendEndHeaders();
			var fin = File.read(actualFilePath, true);
			var bufSize:Int = 81920;
			var buffer:Bytes = Bytes.alloc(bufSize);
			var count:Int;
			try
			{
				while ((count = fin.readBytes(buffer, 0, bufSize) ) != 0) {
					response.remoteClient.output.writeBytes(buffer, 0, count);
				}
			}
			catch (e:Eof)
			{	}
		}
	}
	
	function sendStringToClient(response:HTTPResponse, string:String)
	{
		response.remoteClient.output.writeString(string);
	}
	
	function GenerateDirectoryIndex(response:HTTPResponse, actualFilePath:String) 
	{
		Logger.WriteLine("Generating dynamic index.");
		response.sendHeader("HTTP/1.1 200 OK");
		response.sendHeader("Content-Type: text/html");
		response.sendEndHeaders();
		var indexhtmlbody:String = "<ul>";
		var parentDir:String = Path.addTrailingSlash(Path.directory(actualFilePath));
		var pathList:Array<String> = FileSystem.readDirectory(parentDir);
		var fileList:List<String> = new List<String>();
		var dirList:List<String> = new List<String>();
		
		for (path in pathList)
		{
			path = parentDir + path;
			if (FileSystem.isDirectory(path))
			{
				dirList.add(path);
			}
			else
			{
				fileList.add(path);
			}
		}
		for (path in dirList)
		{
			var dirName:String = Path.withoutDirectory(path);
			var targetAddress:String = response.requestPath + dirName + "/";
			var targetDisplayName:String = dirName + "/";
			indexhtmlbody += "<li><a href=\"" + targetAddress + "\">" + targetDisplayName + "</a><br></li>";
		}
		for (path in fileList)
		{
			var fileName:String = Path.withoutDirectory(path);
			var targetAddress:String = response.requestPath + fileName;
			var targetDisplayName:String = fileName;
			indexhtmlbody += "<li><a href=\"" + targetAddress + "\">" + targetDisplayName + "</a><br></li>";
		}	
		indexhtmlbody+="</ul><p><h5>BurnedHTTP Server</h5></p>";
		var indexhtml:String = "<html><head><title>Index of " + response.requestPath + "</title></head><body>" + indexhtmlbody + "</body></html>";
		return indexhtml;
	}
	override public function HandleGETRequest(response:HTTPResponse) 
	{
		super.HandleGETRequest(response);
		var requestPath = response.requestPath;
		if (StringTools.endsWith(requestPath, "/"))
			requestPath += "index.html";
		SendBytesWithMIMEType(requestPath, response);
		Logger.WriteLine("GET: "+requestPath);
	}
}