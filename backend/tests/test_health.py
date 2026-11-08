def test_health_ok(client):
    res = client.get("/health")
    assert res.status_code == 200
    assert res.json() == {"status": "ok"}


def test_unknown_route_uses_standard_error_model(client):
    res = client.get("/nope")
    assert res.status_code == 404
    body = res.json()
    assert body["code"] == 404
    assert isinstance(body["message"], str)
