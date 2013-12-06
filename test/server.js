var http    = require('http');
var should  = require('should');
var request = require('supertest');
var restler = require('restler');
var fs      = require('fs');

describe('API', function() {
    var url = 'http://localhost:3000';

    before(function(done) {
        done();
    });

    describe('Entity', function() {

        it('should return all items of an entity', function(done) {
            request(url)
                .get('/team/collection')
                .expect(200)
                .expect('Content-Type', /json/)
                .end(function(err,res) {
                    if (err) { throw err; }
                    res.body.should.have.property('response')
                    res.body.response.numFound.should.eql(18)
                    res.body.response.docs.length.should.eql(18)
                    res.body.response.docs[0].should.have.property('id')
                    done();
                });
        });

        it('should return an entity\'s schema', function(done) {
            request(url)
                .get('/team/schema')
                .expect(200)
                .expect('Content-Type', /json/)
                .end(function(err, res) {
                    if (err) { throw err; }
                    res.body.should.be.an.instanceOf(Array);
                    res.body.length.should.eql(16);
                    done();
                });
        });

        it('should return an entity\'s settings', function(done) {
            request(url)
                .get('/team/settings')
                .expect(200)
                .expect('Content-Type', /json/)
                .end(function(err, res) {
                    if (err) { throw err; }
                    res.body.should.be.an.instanceOf(Object);
                    res.body.should.have.property('entity');
                    res.body.should.have.property('title');
                    res.body.should.have.property('itemType');
                    done();
                });
        });

        it('should return an entity\'s pane.json', function(done) {
            request(url)
                .get('/team/pane.json')
                .expect(200)
                .expect('Content-Type', /json/)
                .end(function(err, res) {
                    if (err) { throw err; }
                    res.body.should.be.an.instanceOf(Object);
                    done();
                });
        });

        it('should return an entity\'s facet values', function(done) {
            request(url)
                .get('/team/ufacets')
                .expect(200)
                .expect('Content-Type', /json/)
                .end(function(err, res) {
                    if (err) { throw err; }
                    res.body.should.be.an.instanceOf(Object);
                    res.body.should.have.property('team');
                    res.body.team.should.be.an.instanceOf(Array);
                    res.body.team.length.should.eql(7);
                    done();
                });
        });

        it('should return an entity\'s template', function(done) {
            request(url)
                .get('/team/ufacets')
                .expect(200)
                .expect('Content-Type', /json/)
                .end(function(err, res) {
                    if (err) { throw err; }
                    res.body.should.be.an.instanceOf(Object);
                    res.body.should.have.property('team');
                    res.body.team.should.be.an.instanceOf(Array);
                    res.body.team.length.should.eql(7);
                    done();
                });
        });

        it('should return all members of team Technology', function(done) {
            request(url)
                .get('/team/property/team/Technology')
                .expect(200)
                .expect('Content-Type', /json/)
                .end(function(err, res) {
                    if (err) { throw err; }
                    res.body.should.be.an.instanceOf(Array);
                    res.body.length.should.eql(6);
                    done();
                });
        });
    });


    describe('Item', function() {

        var date = new Date();

        var purl = null;

        var item = {
            "name": "John",
            "lastname": "Doe",
            "email": "john.doe@example.com",
            "startDate": date.toISOString()
        };

        it('should upload a picture', function(done) {
            var filename = './test/picture.jpg';
            fs.stat(filename, function(err, stats) {
                if (err) { throw err; }
                restler.post(url+'/team/picture', {
                    multipart: true,
                    data: {
                        "picture": restler.file(filename, null, stats.size, null, "image/jpeg")
                    }
                }).on("complete", function(data) {
                    item.pic = data[0].url;
                    done();
                });
            });

        });

        it('should create a new item', function(done) {

            request(url)
                .post('/team/collection')
                .send(item)
                .expect(200)
                .end(function(err, res) {
                    if (err) { throw err; }
                    res.body.should.be.an.instanceOf(Object);
                    res.body.should.have.property('id');
                    res.body.should.have.property('name').and.eql('John');
                    res.body.should.have.property('lastname').and.eql('Doe');
                    res.body.should.have.property('email').and.eql('john.doe@example.com');
                    item.id = res.body.id
                    done();
                });
        });

        it('should modify an existing item', function(done) {
            item.name = 'Jon';
            item.team = [ 'team' ];
            item.role = [ 'role' ];
            request(url)
                .put('/team/collection/'+item.id)
                .send(item)
                .expect(200)
                .end(function(err, res) {
                    if (err) { throw err; }
                    res.body.should.be.an.instanceOf(Object);
                    res.body.should.have.property('id');
                    res.body.should.have.property('name').and.eql('Jon');
                    res.body.should.have.property('lastname').and.eql('Doe');
                    res.body.should.have.property('email').and.eql('john.doe@example.com');
                    res.body.should.have.property('team');
                    res.body.should.have.property('role');
                    done();
                });
        });

        it('should modify just one property of an existing item', function(done) {
            request(url)
                .put('/team/'+item.id+'/property/name/John')
                .expect(200)
                .end(function(err, res) {
                    if (err) { throw err; }
                    res.body[0].should.be.an.instanceOf(Object);
                    res.body[0].should.have.property('id');
                    res.body[0].should.have.property('name').and.eql('John');
                    res.body[0].should.have.property('lastname').and.eql('Doe');
                    res.body[0].should.have.property('email').and.eql('john.doe@example.com');
                    res.body[0].should.have.property('team');
                    res.body[0].should.have.property('role');
                    done();
                });
        });

        it('should delete one property of an existing item', function(done) {
            request(url)
                .del('/team/'+item.id+'/property/role/role')
                .expect(200)
                .end(function(err, res) {
                    if (err) { throw err; }
                    res.body[0].should.be.an.instanceOf(Object);
                    res.body[0].should.have.property('id');
                    res.body[0].should.have.property('name').and.eql('John');
                    res.body[0].should.have.property('lastname').and.eql('Doe');
                    res.body[0].should.have.property('email').and.eql('john.doe@example.com');
                    res.body[0].should.have.property('team');
                    res.body[0].should.not.have.property('role');
                    done();
                });
        });

        it('should get an existing item', function(done) {
            request(url)
                .get('/team/collection/'+item.id)
                .expect(200)
                .end(function(err, res) {
                    if (err) { throw err; }
                    res.body.should.be.an.instanceOf(Object);
                    res.body.should.have.property('id');
                    res.body.should.have.property('name').and.eql('John');
                    res.body.should.have.property('lastname').and.eql('Doe');
                    res.body.should.have.property('email').and.eql('john.doe@example.com');
                    res.body.should.have.property('team');
                    res.body.should.not.have.property('role');
                    done();
                });
        });

        it('should delete an existing item', function(done) {
            request(url)
                .del('/team/collection/'+item.id)
                .expect(200)
                .end(function(err, res) {
                    if (err) { throw err; }
                    done();
                });
        });

        it('should have deleted the image', function(done) {
            fs.stat('..'+item.pic, function (err, stats) {
                err.should.have.property('code').and.eql('ENOENT');
                done();
            });
        });

    });

});
