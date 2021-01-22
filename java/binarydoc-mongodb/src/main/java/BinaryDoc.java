import com.mongodb.Block;
import com.mongodb.client.MongoClient;
import com.mongodb.client.MongoClients;
import com.mongodb.client.MongoCursor;
import com.mongodb.client.MongoDatabase;
import com.mongodb.client.gridfs.*;
import com.mongodb.client.gridfs.model.GridFSFile;
import com.mongodb.client.gridfs.model.GridFSUploadOptions;
import org.bson.Document;

import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import static com.mongodb.client.model.Filters.eq;

public class BinaryDoc {
    private MongoDatabase db;
    private GridFSBucket bucket;
    private String document_id;
    private GridFSDownloadStream ds;
    private GridFSUploadStream us;

    public BinaryDoc(String db, String coll, String document_id){
        MongoClient conn = MongoClients.create();
        this.db = conn.getDatabase(db);
        this.bucket = GridFSBuckets.create(this.db, "did");
    }

    public void open(){
        this.ds = bucket.openDownloadStream(document_id + ".bin");
    }

    public byte[] read(int count){
        if (this.us == null){
            throw new IllegalStateException("Cannot read: file is empty");
        }
        byte[] bytesToWriteTo = new byte[count];
        this.ds.read(bytesToWriteTo);
        this.ds.close();
        return bytesToWriteTo;
    }

    public void write(byte[] data){
        if (this.us == null){
            throw new IllegalStateException("Will figure out how to update later");
        }
        GridFSUploadOptions options = new GridFSUploadOptions()
                .chunkSizeBytes(358400)
                .metadata(new Document("document_id", this.document_id));

        GridFSUploadStream uploadStream = bucket.openUploadStream(this.document_id + ".bin", options);
        uploadStream.write(data);
        uploadStream.close();
    }
}
